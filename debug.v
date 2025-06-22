module gui

type PrintMany = string | bool | i8 | i16 | int | i64 | u8 | u16 | u32 | u64 | rune | f32 | f64

fn print_many(strs ...PrintMany) {
	println(strs.map(it.str().replace('gui.PrintMany(', '')#[..-1]).join(', '))
}

fn log(err IError) {
	eprintln(err.msg())
}
