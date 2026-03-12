use alloy_json_abi::{
    Constructor, Error as AbiError, Event, EventParam, Function, JsonAbi, Param, StateMutability,
};
use rustler::{Encoder, Env, NifResult, Term};
use solang_parser::pt;
use tiny_keccak::{Hasher, Keccak};

mod atoms {
    rustler::atoms! {
        ok,
        error,
        parse_error,

        // Map keys
        name,
        signature,
        selector,
        return_type,
        state_mutability,
        inputs,
        outputs,
        functions,
        events,
        errors,
        constructor,
        anonymous,
        topic,
        indexed,
        ty, // "type" is reserved in Rust
        components,

        // New keys for .sol parsing
        structs,
        enums,
        constants,
        natspec,
        notice,
        params,
        returns,
        fields,
        variants,
        value,
    }
}

// --- NIF functions ---

#[rustler::nif]
fn parse_abi_json<'a>(env: Env<'a>, json: &str) -> NifResult<Term<'a>> {
    match serde_json::from_str::<JsonAbi>(json) {
        Ok(abi) => {
            let result = encode_abi(env, &abi);
            Ok((atoms::ok(), result).encode(env))
        }
        Err(e) => {
            let reason = format!("{}", e);
            Ok((atoms::error(), (atoms::parse_error(), reason)).encode(env))
        }
    }
}

#[rustler::nif]
fn parse_sol<'a>(env: Env<'a>, source: &str) -> NifResult<Term<'a>> {
    let (tree, _comments) = match solang_parser::parse(source, 0) {
        Ok(result) => result,
        Err(diags) => {
            let msgs: Vec<String> = diags.iter().map(|d| format!("{:?}", d)).collect();
            let reason = msgs.join("; ");
            return Ok((atoms::error(), (atoms::parse_error(), reason)).encode(env));
        }
    };

    // Extract doc comments from the source for NatSpec.
    // Uses a mutable vec to mark consumed entries.
    let mut doc_comments = extract_doc_comments(source);

    // Walk the AST to extract structs, enums, constants, and functions
    let mut sol_structs: Vec<Term<'a>> = Vec::new();
    let mut sol_enums: Vec<Term<'a>> = Vec::new();
    let mut sol_constants: Vec<Term<'a>> = Vec::new();
    let mut sol_functions: Vec<Term<'a>> = Vec::new();
    let mut sol_events: Vec<Term<'a>> = Vec::new();
    let mut sol_errors: Vec<Term<'a>> = Vec::new();
    let mut sol_constructor: Term<'a> = rustler::types::atom::nil().encode(env);

    // Collect struct definitions for resolving tuple types
    let mut struct_defs: Vec<SolStruct> = Vec::new();

    for part in &tree.0 {
        match part {
            pt::SourceUnitPart::ContractDefinition(contract) => {
                // First pass: collect struct definitions
                for part in &contract.parts {
                    if let pt::ContractPart::StructDefinition(s) = part {
                        let fields: Vec<SolField> = s
                            .fields
                            .iter()
                            .map(|f| SolField {
                                name: f.name.as_ref().map(|id| id.name.clone()).unwrap_or_default(),
                                ty: expr_to_type_string(&f.ty),
                            })
                            .collect();
                        struct_defs.push(SolStruct {
                            name: s.name.as_ref().map(|id| id.name.clone()).unwrap_or_default(),
                            fields,
                        });
                    }
                }

                // Second pass: process all parts
                for part in &contract.parts {
                    match part {
                        pt::ContractPart::StructDefinition(s) => {
                            sol_structs.push(encode_sol_struct(env, s));
                        }
                        pt::ContractPart::EnumDefinition(e) => {
                            sol_enums.push(encode_sol_enum(env, e));
                        }
                        pt::ContractPart::VariableDefinition(v) => {
                            if let Some(c) = encode_sol_constant(env, v) {
                                sol_constants.push(c);
                            }
                        }
                        pt::ContractPart::FunctionDefinition(f) => {
                            match &f.ty {
                                pt::FunctionTy::Constructor => {
                                    sol_constructor =
                                        encode_sol_constructor(env, f, &struct_defs);
                                }
                                pt::FunctionTy::Function => {
                                    let natspec = take_natspec_for_offset(
                                        &mut doc_comments,
                                        f.loc.start(),
                                    );
                                    sol_functions.push(encode_sol_function(
                                        env,
                                        f,
                                        natspec.as_ref(),
                                        &struct_defs,
                                    ));
                                }
                                _ => {}
                            }
                        }
                        pt::ContractPart::EventDefinition(e) => {
                            sol_events.push(encode_sol_event(env, e, &struct_defs));
                        }
                        pt::ContractPart::ErrorDefinition(e) => {
                            sol_errors.push(encode_sol_error(env, e, &struct_defs));
                        }
                        _ => {}
                    }
                }
            }
            _ => {}
        }
    }

    let mut map = Term::map_new(env);
    map = map_put(map, atoms::functions().encode(env), sol_functions.encode(env));
    map = map_put(map, atoms::events().encode(env), sol_events.encode(env));
    map = map_put(map, atoms::errors().encode(env), sol_errors.encode(env));
    map = map_put(map, atoms::constructor().encode(env), sol_constructor);
    map = map_put(map, atoms::structs().encode(env), sol_structs.encode(env));
    map = map_put(map, atoms::enums().encode(env), sol_enums.encode(env));
    map = map_put(
        map,
        atoms::constants().encode(env),
        sol_constants.encode(env),
    );

    Ok((atoms::ok(), map).encode(env))
}

// --- Struct definitions for internal use ---

#[derive(Clone)]
struct SolStruct {
    name: String,
    fields: Vec<SolField>,
}

#[derive(Clone)]
struct SolField {
    name: String,
    ty: String,
}

struct NatSpecComment {
    notice: String,
    params: Vec<(String, String)>,
    returns: Vec<(String, String)>,
}

// --- Solidity source encoding helpers ---

fn encode_sol_struct<'a>(env: Env<'a>, s: &pt::StructDefinition) -> Term<'a> {
    let name_str = s.name.as_ref().map(|id| id.name.as_str()).unwrap_or("");
    let fields: Vec<Term<'a>> = s
        .fields
        .iter()
        .map(|f| {
            let fname = f.name.as_ref().map(|id| id.name.as_str()).unwrap_or("");
            let fty = expr_to_type_string(&f.ty);
            let mut m = Term::map_new(env);
            m = map_put(m, atoms::name().encode(env), fname.encode(env));
            m = map_put(m, atoms::ty().encode(env), fty.as_str().encode(env));
            m
        })
        .collect();

    let mut map = Term::map_new(env);
    map = map_put(map, atoms::name().encode(env), name_str.encode(env));
    map = map_put(map, atoms::fields().encode(env), fields.encode(env));
    map
}

fn encode_sol_enum<'a>(env: Env<'a>, e: &pt::EnumDefinition) -> Term<'a> {
    let name_str = e.name.as_ref().map(|id| id.name.as_str()).unwrap_or("");
    let variants: Vec<&str> = e
        .values
        .iter()
        .map(|v| v.as_ref().map(|id| id.name.as_str()).unwrap_or(""))
        .collect();

    let mut map = Term::map_new(env);
    map = map_put(map, atoms::name().encode(env), name_str.encode(env));
    map = map_put(map, atoms::variants().encode(env), variants.encode(env));
    map
}

fn encode_sol_constant<'a>(env: Env<'a>, v: &pt::VariableDefinition) -> Option<Term<'a>> {
    // Only include constant/immutable variables
    let is_constant = v.attrs.iter().any(|a| {
        matches!(
            a,
            pt::VariableAttribute::Constant(_) | pt::VariableAttribute::Immutable(_)
        )
    });
    if !is_constant {
        return None;
    }

    let name_str = v.name.as_ref().map(|id| id.name.as_str()).unwrap_or("");
    let ty_str = expr_to_type_string(&v.ty);
    let val_str = v
        .initializer
        .as_ref()
        .map(|e| expr_to_value_string(e))
        .unwrap_or_default();

    let mut map = Term::map_new(env);
    map = map_put(map, atoms::name().encode(env), name_str.encode(env));
    map = map_put(map, atoms::ty().encode(env), ty_str.as_str().encode(env));
    map = map_put(map, atoms::value().encode(env), val_str.as_str().encode(env));
    Some(map)
}

fn encode_sol_function<'a>(
    env: Env<'a>,
    f: &pt::FunctionDefinition,
    natspec: Option<&NatSpecComment>,
    struct_defs: &[SolStruct],
) -> Term<'a> {
    let name_str = f.name.as_ref().map(|id| id.name.as_str()).unwrap_or("");

    // Build inputs
    let input_types: Vec<String> = f
        .params
        .iter()
        .map(|(_, p)| param_to_canonical_type(p, struct_defs))
        .collect();

    let ins: Vec<Term<'a>> = f
        .params
        .iter()
        .map(|(_, p)| encode_sol_param(env, p, struct_defs))
        .collect();

    // Build outputs
    let output_types: Vec<String> = f
        .returns
        .iter()
        .map(|(_, p)| param_to_canonical_type(p, struct_defs))
        .collect();

    let outs: Vec<Term<'a>> = f
        .returns
        .iter()
        .map(|(_, p)| encode_sol_param(env, p, struct_defs))
        .collect();

    // Build signature: name(type1,type2)
    let sig = format!("{}({})", name_str, input_types.join(","));

    // Compute selector (first 4 bytes of keccak256)
    let selector = compute_selector(&sig);

    // Build return_type: (type1,type2)
    let ret = format!("({})", output_types.join(","));

    // State mutability
    let mutability = sol_function_mutability(f);

    // NatSpec
    let natspec_term = match natspec {
        Some(ns) => {
            let mut m = Term::map_new(env);
            m = map_put(m, atoms::notice().encode(env), ns.notice.as_str().encode(env));

            let mut pm = Term::map_new(env);
            for (k, v) in &ns.params {
                pm = map_put(pm, k.as_str().encode(env), v.as_str().encode(env));
            }
            m = map_put(m, atoms::params().encode(env), pm);

            let mut rm = Term::map_new(env);
            for (k, v) in &ns.returns {
                rm = map_put(rm, k.as_str().encode(env), v.as_str().encode(env));
            }
            m = map_put(m, atoms::returns().encode(env), rm);
            m
        }
        None => rustler::types::atom::nil().encode(env),
    };

    let mut map = Term::map_new(env);
    map = map_put(map, atoms::name().encode(env), name_str.encode(env));
    map = map_put(map, atoms::signature().encode(env), sig.as_str().encode(env));
    map = map_put(
        map,
        atoms::selector().encode(env),
        selector.as_str().encode(env),
    );
    map = map_put(map, atoms::return_type().encode(env), ret.as_str().encode(env));
    map = map_put(
        map,
        atoms::state_mutability().encode(env),
        mutability.encode(env),
    );
    map = map_put(map, atoms::inputs().encode(env), ins.encode(env));
    map = map_put(map, atoms::outputs().encode(env), outs.encode(env));
    map = map_put(map, atoms::natspec().encode(env), natspec_term);
    map
}

fn encode_sol_constructor<'a>(
    env: Env<'a>,
    f: &pt::FunctionDefinition,
    struct_defs: &[SolStruct],
) -> Term<'a> {
    let ins: Vec<Term<'a>> = f
        .params
        .iter()
        .map(|(_, p)| encode_sol_param(env, p, struct_defs))
        .collect();

    let mutability = sol_function_mutability(f);

    let mut map = Term::map_new(env);
    map = map_put(map, atoms::inputs().encode(env), ins.encode(env));
    map = map_put(
        map,
        atoms::state_mutability().encode(env),
        mutability.encode(env),
    );
    map
}

fn encode_sol_event<'a>(
    env: Env<'a>,
    e: &pt::EventDefinition,
    struct_defs: &[SolStruct],
) -> Term<'a> {
    let name_str = e.name.as_ref().map(|id| id.name.as_str()).unwrap_or("");

    let input_types: Vec<String> = e
        .fields
        .iter()
        .map(|p| {
            let raw = expr_to_type_string(&p.ty);
            type_to_canonical(&raw, struct_defs)
        })
        .collect();

    let sig = format!("{}({})", name_str, input_types.join(","));
    let topic_hash = compute_topic_hash(&sig);

    let ins: Vec<Term<'a>> = e
        .fields
        .iter()
        .map(|p| {
            let pname = p.name.as_ref().map(|id| id.name.as_str()).unwrap_or("");
            let raw_ty = expr_to_type_string(&p.ty);
            let (canonical_ty, components) = resolve_struct_type(&raw_ty, struct_defs);

            let comps: Vec<Term<'a>> = components
                .iter()
                .map(|f| encode_sol_field(env, f, struct_defs))
                .collect();

            let mut m = Term::map_new(env);
            m = map_put(m, atoms::name().encode(env), pname.encode(env));
            m = map_put(m, atoms::ty().encode(env), canonical_ty.as_str().encode(env));
            m = map_put(m, atoms::indexed().encode(env), p.indexed.encode(env));
            m = map_put(m, atoms::components().encode(env), comps.encode(env));
            m
        })
        .collect();

    let is_anonymous = e.anonymous;

    let mut map = Term::map_new(env);
    map = map_put(map, atoms::name().encode(env), name_str.encode(env));
    map = map_put(map, atoms::signature().encode(env), sig.as_str().encode(env));
    map = map_put(
        map,
        atoms::topic().encode(env),
        topic_hash.as_str().encode(env),
    );
    map = map_put(
        map,
        atoms::anonymous().encode(env),
        is_anonymous.encode(env),
    );
    map = map_put(map, atoms::inputs().encode(env), ins.encode(env));
    map
}

fn encode_sol_error<'a>(
    env: Env<'a>,
    e: &pt::ErrorDefinition,
    struct_defs: &[SolStruct],
) -> Term<'a> {
    let name_str = e.name.as_ref().map(|id| id.name.as_str()).unwrap_or("");

    let input_types: Vec<String> = e
        .fields
        .iter()
        .map(|p| {
            let raw = expr_to_type_string(&p.ty);
            type_to_canonical(&raw, struct_defs)
        })
        .collect();

    let sig = format!("{}({})", name_str, input_types.join(","));
    let selector = compute_selector(&sig);

    let ins: Vec<Term<'a>> = e
        .fields
        .iter()
        .map(|p| {
            let pname = p.name.as_ref().map(|id| id.name.as_str()).unwrap_or("");
            let raw_ty = expr_to_type_string(&p.ty);
            let (canonical_ty, components) = resolve_struct_type(&raw_ty, struct_defs);

            let comps: Vec<Term<'a>> = components
                .iter()
                .map(|f| encode_sol_field(env, f, struct_defs))
                .collect();

            let mut m = Term::map_new(env);
            m = map_put(m, atoms::name().encode(env), pname.encode(env));
            m = map_put(m, atoms::ty().encode(env), canonical_ty.as_str().encode(env));
            m = map_put(m, atoms::components().encode(env), comps.encode(env));
            m
        })
        .collect();

    let mut map = Term::map_new(env);
    map = map_put(map, atoms::name().encode(env), name_str.encode(env));
    map = map_put(map, atoms::signature().encode(env), sig.as_str().encode(env));
    map = map_put(
        map,
        atoms::selector().encode(env),
        selector.as_str().encode(env),
    );
    map = map_put(map, atoms::inputs().encode(env), ins.encode(env));
    map
}

fn encode_sol_param<'a>(
    env: Env<'a>,
    p: &Option<pt::Parameter>,
    struct_defs: &[SolStruct],
) -> Term<'a> {
    match p {
        Some(param) => {
            let pname = param
                .name
                .as_ref()
                .map(|id| id.name.as_str())
                .unwrap_or("");
            let raw_ty = expr_to_type_string(&param.ty);

            // Check if the type references a known struct
            let (canonical_ty, components) = resolve_struct_type(&raw_ty, struct_defs);

            let comps: Vec<Term<'a>> = components
                .iter()
                .map(|f| encode_sol_field(env, f, struct_defs))
                .collect();

            let mut m = Term::map_new(env);
            m = map_put(m, atoms::name().encode(env), pname.encode(env));
            m = map_put(m, atoms::ty().encode(env), canonical_ty.as_str().encode(env));
            m = map_put(m, atoms::components().encode(env), comps.encode(env));
            m
        }
        None => {
            let mut m = Term::map_new(env);
            m = map_put(m, atoms::name().encode(env), "".encode(env));
            m = map_put(m, atoms::ty().encode(env), "".encode(env));
            m = map_put(
                m,
                atoms::components().encode(env),
                Vec::<Term<'a>>::new().encode(env),
            );
            m
        }
    }
}

/// Resolve a type that may reference a struct definition.
/// Returns (canonical_type, components) where:
/// - If it's a struct: ("tuple", [fields...]) or ("tuple[]", [fields...])
/// - If it's a primitive: (type_string, [])
fn resolve_struct_type(ty: &str, struct_defs: &[SolStruct]) -> (String, Vec<SolField>) {
    // Check for array suffix
    let (base_ty, suffix) = if ty.ends_with("[]") {
        (&ty[..ty.len() - 2], "[]")
    } else {
        (ty, "")
    };

    // Look up in struct definitions
    for s in struct_defs {
        if s.name == base_ty {
            let canonical = format!("tuple{}", suffix);
            return (canonical, s.fields.clone());
        }
    }

    // Not a struct — return as-is
    (ty.to_string(), Vec::new())
}

/// Recursively resolve a type string to its canonical ABI form.
/// Struct names become expanded tuple types (e.g., "UserData" → "(uint256,address,bool)").
/// Handles nested structs: a struct field that references another struct is expanded recursively.
fn type_to_canonical(ty: &str, struct_defs: &[SolStruct]) -> String {
    let (base_ty, suffix) = if ty.ends_with("[]") {
        (&ty[..ty.len() - 2], "[]")
    } else {
        (ty, "")
    };

    for s in struct_defs {
        if s.name == base_ty {
            let inner: Vec<String> = s
                .fields
                .iter()
                .map(|f| type_to_canonical(&f.ty, struct_defs))
                .collect();
            return format!("({}){}", inner.join(","), suffix);
        }
    }

    format!("{}{}", base_ty, suffix)
}

/// Encode a SolField as a Rustler term, recursively resolving nested struct types.
fn encode_sol_field<'a>(env: Env<'a>, field: &SolField, struct_defs: &[SolStruct]) -> Term<'a> {
    let (canonical_ty, components) = resolve_struct_type(&field.ty, struct_defs);

    let comps: Vec<Term<'a>> = components
        .iter()
        .map(|f| encode_sol_field(env, f, struct_defs))
        .collect();

    let mut m = Term::map_new(env);
    m = map_put(m, atoms::name().encode(env), field.name.as_str().encode(env));
    m = map_put(m, atoms::ty().encode(env), canonical_ty.as_str().encode(env));
    m = map_put(m, atoms::components().encode(env), comps.encode(env));
    m
}

/// Get the canonical type for a parameter, resolving struct references to tuple types.
fn param_to_canonical_type(p: &Option<pt::Parameter>, struct_defs: &[SolStruct]) -> String {
    match p {
        Some(param) => {
            let raw = expr_to_type_string(&param.ty);
            type_to_canonical(&raw, struct_defs)
        }
        None => String::new(),
    }
}

// --- Type expression to string conversion ---

fn expr_to_type_string(expr: &pt::Expression) -> String {
    match expr {
        pt::Expression::Type(_, ty) => match ty {
            pt::Type::Address => "address".to_string(),
            pt::Type::AddressPayable => "address".to_string(),
            pt::Type::Bool => "bool".to_string(),
            pt::Type::String => "string".to_string(),
            pt::Type::Bytes(n) => format!("bytes{}", n),
            pt::Type::DynamicBytes => "bytes".to_string(),
            pt::Type::Int(n) => format!("int{}", n),
            pt::Type::Uint(n) => format!("uint{}", n),
            pt::Type::Mapping { .. } => "mapping".to_string(),
            _ => format!("{:?}", ty),
        },
        pt::Expression::ArraySubscript(_, base, _) => {
            format!("{}[]", expr_to_type_string(base))
        }
        pt::Expression::Variable(id) => {
            // This handles custom type references (struct names, enum names)
            id.name.clone()
        }
        _ => format!("{:?}", expr),
    }
}

fn expr_to_value_string(expr: &pt::Expression) -> String {
    match expr {
        pt::Expression::NumberLiteral(_, val, _, _) => val.clone(),
        pt::Expression::HexNumberLiteral(_, val, _) => val.clone(),
        pt::Expression::StringLiteral(vals) => {
            vals.iter().map(|s| s.string.clone()).collect::<String>()
        }
        pt::Expression::BoolLiteral(_, b) => b.to_string(),
        _ => format!("{:?}", expr),
    }
}

fn sol_function_mutability(f: &pt::FunctionDefinition) -> &'static str {
    for attr in &f.attributes {
        match attr {
            pt::FunctionAttribute::Mutability(m) => match m {
                pt::Mutability::Pure(_) => return "pure",
                pt::Mutability::View(_) => return "view",
                pt::Mutability::Payable(_) => return "payable",
                pt::Mutability::Constant(_) => return "view",
            },
            _ => {}
        }
    }
    "nonpayable"
}

// --- Keccak-256 via tiny-keccak ---

fn keccak256(data: &[u8]) -> [u8; 32] {
    let mut hasher = Keccak::v256();
    hasher.update(data);
    let mut output = [0u8; 32];
    hasher.finalize(&mut output);
    output
}

fn compute_selector(signature: &str) -> String {
    let hash = keccak256(signature.as_bytes());
    format!("0x{}", hex::encode(&hash[..4]))
}

fn compute_topic_hash(signature: &str) -> String {
    let hash = keccak256(signature.as_bytes());
    format!("0x{}", hex::encode(&hash))
}

// --- NatSpec comment extraction ---

/// Extract doc comments (/// and /** */) from source.
/// Returns a map of byte_offset → NatSpecComment where byte_offset is the start
/// of the first non-comment line after the doc comment block.
fn extract_doc_comments(source: &str) -> Vec<(usize, NatSpecComment)> {
    let lines: Vec<&str> = source.lines().collect();
    let mut results: Vec<(usize, NatSpecComment)> = Vec::new();

    // Build a cumulative byte offset table: byte_offsets[i] = byte offset of line i
    let mut byte_offsets: Vec<usize> = Vec::with_capacity(lines.len() + 1);
    let mut offset = 0;
    for line in &lines {
        byte_offsets.push(offset);
        offset += line.len() + 1; // +1 for newline
    }
    byte_offsets.push(offset); // sentinel for past-end

    let mut i = 0;
    while i < lines.len() {
        let trimmed = lines[i].trim();

        // Check for /// style doc comments
        if trimmed.starts_with("///") {
            let mut doc_lines: Vec<&str> = Vec::new();

            while i < lines.len() && lines[i].trim().starts_with("///") {
                let line = lines[i].trim().trim_start_matches("///").trim();
                doc_lines.push(line);
                i += 1;
            }

            // Skip blank lines between doc comment and definition
            while i < lines.len() && lines[i].trim().is_empty() {
                i += 1;
            }

            // target_line_offset = byte offset of the definition line
            if i < lines.len() {
                if let Some(ns) = parse_natspec_lines(&doc_lines) {
                    results.push((byte_offsets[i], ns));
                }
            }
            continue;
        }

        // Check for /** ... */ style block doc comments
        if trimmed.starts_with("/**") {
            let mut doc_lines: Vec<&str> = Vec::new();

            if trimmed.ends_with("*/") {
                // Single-line block comment: /** @notice foo */
                let content = trimmed
                    .trim_start_matches("/**")
                    .trim_end_matches("*/")
                    .trim();
                if !content.is_empty() {
                    doc_lines.push(content);
                }
                i += 1;
            } else {
                // Multi-line block comment
                let first = trimmed.trim_start_matches("/**").trim();
                if !first.is_empty() {
                    doc_lines.push(first);
                }
                i += 1;

                while i < lines.len() {
                    let line = lines[i].trim();
                    if line.ends_with("*/") || line == "*/" {
                        let content = line
                            .trim_end_matches("*/")
                            .trim()
                            .trim_start_matches('*')
                            .trim();
                        if !content.is_empty() {
                            doc_lines.push(content);
                        }
                        i += 1;
                        break;
                    } else {
                        let content = line.trim_start_matches('*').trim();
                        if !content.is_empty() {
                            doc_lines.push(content);
                        }
                        i += 1;
                    }
                }
            }

            // Skip blank lines between doc comment and definition
            while i < lines.len() && lines[i].trim().is_empty() {
                i += 1;
            }

            if i < lines.len() {
                if let Some(ns) = parse_natspec_lines(&doc_lines) {
                    results.push((byte_offsets[i], ns));
                }
            }
            continue;
        }

        i += 1;
    }

    results
}

fn parse_natspec_lines(lines: &[&str]) -> Option<NatSpecComment> {
    let mut notice = String::new();
    let mut params: Vec<(String, String)> = Vec::new();
    let mut returns: Vec<(String, String)> = Vec::new();

    for line in lines {
        let line = line.trim();
        if line.starts_with("@notice ") {
            notice = line.trim_start_matches("@notice ").to_string();
        } else if line.starts_with("@param ") {
            let rest = line.trim_start_matches("@param ");
            if let Some(pos) = rest.find(' ') {
                params.push((rest[..pos].to_string(), rest[pos + 1..].to_string()));
            }
        } else if line.starts_with("@return ") {
            let rest = line.trim_start_matches("@return ");
            if let Some(pos) = rest.find(' ') {
                returns.push((rest[..pos].to_string(), rest[pos + 1..].to_string()));
            }
        } else if line.starts_with("@title ") || line.starts_with("@dev ") || line.starts_with("@author ") {
            // Skip @title, @dev, @author
        } else if !line.is_empty() && notice.is_empty() {
            // Bare doc comment without tag — treat as notice
            notice = line.to_string();
        }
    }

    if notice.is_empty() && params.is_empty() && returns.is_empty() {
        return None;
    }

    Some(NatSpecComment {
        notice,
        params,
        returns,
    })
}

/// Find and consume the NatSpec comment targeting this function.
/// Each doc comment is consumed at most once — prevents bleeding to adjacent functions.
fn take_natspec_for_offset(
    doc_comments: &mut Vec<(usize, NatSpecComment)>,
    func_byte_offset: usize,
) -> Option<NatSpecComment> {
    // Find the closest doc comment whose target offset is <= func_byte_offset
    let mut best_idx: Option<usize> = None;
    let mut best_distance = usize::MAX;

    for (i, (offset, _)) in doc_comments.iter().enumerate() {
        if *offset <= func_byte_offset {
            let distance = func_byte_offset - *offset;
            if distance < best_distance {
                best_idx = Some(i);
                best_distance = distance;
            }
        }
    }

    // Only match if within ~100 bytes (a couple lines of whitespace)
    match best_idx {
        Some(idx) if best_distance < 100 => {
            let (_, ns) = doc_comments.remove(idx);
            Some(ns)
        }
        _ => None,
    }
}

// --- ABI JSON encoding helpers (unchanged) ---

fn encode_abi<'a>(env: Env<'a>, abi: &JsonAbi) -> Term<'a> {
    let funcs: Vec<Term<'a>> = abi.functions().map(|f| encode_function(env, f)).collect();
    let evts: Vec<Term<'a>> = abi.events().map(|e| encode_event(env, e)).collect();
    let errs: Vec<Term<'a>> = abi.errors().map(|e| encode_error(env, e)).collect();

    let ctor: Term<'a> = match &abi.constructor {
        Some(c) => encode_constructor(env, c),
        None => rustler::types::atom::nil().encode(env),
    };

    let mut map = Term::map_new(env);
    map = map_put(map, atoms::functions().encode(env), funcs.encode(env));
    map = map_put(map, atoms::events().encode(env), evts.encode(env));
    map = map_put(map, atoms::errors().encode(env), errs.encode(env));
    map = map_put(map, atoms::constructor().encode(env), ctor);
    map
}

fn encode_function<'a>(env: Env<'a>, f: &Function) -> Term<'a> {
    let sig = f.signature();
    let sel = format!("0x{}", hex::encode(f.selector().as_ref() as &[u8]));
    let ret = build_return_type(&f.outputs);
    let mutability = mutability_str(&f.state_mutability);

    let ins: Vec<Term<'a>> = f.inputs.iter().map(|p| encode_param(env, p)).collect();
    let outs: Vec<Term<'a>> = f.outputs.iter().map(|p| encode_param(env, p)).collect();

    let mut map = Term::map_new(env);
    map = map_put(map, atoms::name().encode(env), f.name.as_str().encode(env));
    map = map_put(map, atoms::signature().encode(env), sig.as_str().encode(env));
    map = map_put(map, atoms::selector().encode(env), sel.as_str().encode(env));
    map = map_put(map, atoms::return_type().encode(env), ret.as_str().encode(env));
    map = map_put(
        map,
        atoms::state_mutability().encode(env),
        mutability.encode(env),
    );
    map = map_put(map, atoms::inputs().encode(env), ins.encode(env));
    map = map_put(map, atoms::outputs().encode(env), outs.encode(env));
    map
}

fn encode_event<'a>(env: Env<'a>, e: &Event) -> Term<'a> {
    let sig = e.signature();
    let topic_hash = format!("0x{}", hex::encode(e.selector().as_ref() as &[u8]));

    let ins: Vec<Term<'a>> = e.inputs.iter().map(|p| encode_event_param(env, p)).collect();

    let mut map = Term::map_new(env);
    map = map_put(map, atoms::name().encode(env), e.name.as_str().encode(env));
    map = map_put(map, atoms::signature().encode(env), sig.as_str().encode(env));
    map = map_put(map, atoms::topic().encode(env), topic_hash.as_str().encode(env));
    map = map_put(map, atoms::anonymous().encode(env), e.anonymous.encode(env));
    map = map_put(map, atoms::inputs().encode(env), ins.encode(env));
    map
}

fn encode_error<'a>(env: Env<'a>, e: &AbiError) -> Term<'a> {
    let sig = e.signature();
    let sel = format!("0x{}", hex::encode(e.selector().as_ref() as &[u8]));

    let ins: Vec<Term<'a>> = e.inputs.iter().map(|p| encode_param(env, p)).collect();

    let mut map = Term::map_new(env);
    map = map_put(map, atoms::name().encode(env), e.name.as_str().encode(env));
    map = map_put(map, atoms::signature().encode(env), sig.as_str().encode(env));
    map = map_put(map, atoms::selector().encode(env), sel.as_str().encode(env));
    map = map_put(map, atoms::inputs().encode(env), ins.encode(env));
    map
}

fn encode_constructor<'a>(env: Env<'a>, c: &Constructor) -> Term<'a> {
    let mutability = mutability_str(&c.state_mutability);
    let ins: Vec<Term<'a>> = c.inputs.iter().map(|p| encode_param(env, p)).collect();

    let mut map = Term::map_new(env);
    map = map_put(map, atoms::inputs().encode(env), ins.encode(env));
    map = map_put(
        map,
        atoms::state_mutability().encode(env),
        mutability.encode(env),
    );
    map
}

fn encode_param<'a>(env: Env<'a>, p: &Param) -> Term<'a> {
    let comps: Vec<Term<'a>> = p.components.iter().map(|c| encode_param(env, c)).collect();

    let mut map = Term::map_new(env);
    map = map_put(map, atoms::name().encode(env), p.name.as_str().encode(env));
    map = map_put(map, atoms::ty().encode(env), p.ty.as_str().encode(env));
    map = map_put(map, atoms::components().encode(env), comps.encode(env));
    map
}

fn encode_event_param<'a>(env: Env<'a>, p: &EventParam) -> Term<'a> {
    let comps: Vec<Term<'a>> = p.components.iter().map(|c| encode_param(env, c)).collect();

    let mut map = Term::map_new(env);
    map = map_put(map, atoms::name().encode(env), p.name.as_str().encode(env));
    map = map_put(map, atoms::ty().encode(env), p.ty.as_str().encode(env));
    map = map_put(map, atoms::indexed().encode(env), p.indexed.encode(env));
    map = map_put(map, atoms::components().encode(env), comps.encode(env));
    map
}

// --- Helpers ---

/// Build the return type string compatible with Onchain.ABI.decode_response/2.
/// E.g., "(uint256,uint256,bool)" or "(uint256)" for single returns.
fn build_return_type(outputs: &[Param]) -> String {
    if outputs.is_empty() {
        return String::from("()");
    }

    let types: Vec<String> = outputs.iter().map(|p| canonical_type(p)).collect();
    format!("({})", types.join(","))
}

/// Get the canonical type string for a param, handling tuple/struct types recursively.
fn canonical_type(p: &Param) -> String {
    if p.components.is_empty() {
        // Simple type — use the ty field directly
        p.ty.clone()
    } else {
        // Tuple/struct type — build from components
        // Handle array of tuples (e.g., "tuple[]")
        let suffix = if p.ty.starts_with("tuple") {
            &p.ty["tuple".len()..]
        } else {
            ""
        };
        let inner: Vec<String> = p.components.iter().map(|c| canonical_type(c)).collect();
        format!("({}){}", inner.join(","), suffix)
    }
}

/// Convert StateMutability enum to its Solidity string representation.
fn mutability_str(m: &StateMutability) -> &'static str {
    match m {
        StateMutability::Pure => "pure",
        StateMutability::View => "view",
        StateMutability::NonPayable => "nonpayable",
        StateMutability::Payable => "payable",
    }
}

/// Helper to put a key-value pair into a map term.
fn map_put<'a>(map: Term<'a>, key: Term<'a>, value: Term<'a>) -> Term<'a> {
    map.map_put(key, value).expect("failed to put map entry")
}

rustler::init!("Elixir.Onchain.Solidity");
