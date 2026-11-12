use mlua::prelude::*;
use std::path::Path;
fn main() -> LuaResult<()> {
    let path = std::env::args().nth(1).expect("script path");
    let lua = Lua::new();
    let g = lua.globals();
    g.set("read_file", lua.create_function(|_, p: String| Ok(std::fs::read_to_string(&p).ok()))?)?;
    g.set("is_dir", lua.create_function(|_, p: String| Ok(Path::new(&p).is_dir()))?)?;
    g.set("list_dir", lua.create_function(|lua, p: String| {
        let t = lua.create_table()?;
        if let Ok(rd) = std::fs::read_dir(&p) {
            let mut names: Vec<String> = rd.filter_map(|e| e.ok()).map(|e| e.file_name().to_string_lossy().to_string()).collect();
            names.sort();
            for (i, n) in names.into_iter().enumerate() { t.set(i + 1, n)?; }
        }
        Ok(t)
    })?)?;
    g.set("compile_check", lua.create_function(|lua, (src, name): (String, String)| {
        match lua.load(&src).set_name(name).into_function() {
            Ok(_) => Ok(None),
            Err(e) => Ok(Some(e.to_string())),
        }
    })?)?;
    g.set("load_module", lua.create_function(|lua, (src, name, env): (String, String, LuaTable)| {
        let f = lua.load(&src).set_name(name).set_environment(env).into_function()?;
        f.call::<LuaMultiValue>(())
    })?)?;
    let src = std::fs::read_to_string(&path).expect("read");
    let r = lua.load(&src).set_name(path).exec();
    if let Err(e) = &r { eprintln!("{}", e); std::process::exit(1); }
    Ok(())
}
