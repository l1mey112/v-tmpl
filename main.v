import os

type Any = []Any | bool | f32 | f64 | i64 | int | map[string]Any | string | u64

fn main() {
	execute_template('use.tmpl', 'out.tmpl', {})!
}

fn insert_template_code(line string) string {
	// HTML, may include `@var`
	// escaped by cgen, unless it's a `vweb.RawHtml` string
	// trailing_bs := parser.tmpl_str_end + 'sb_${fn_name}.write_u8(92)\n' + tmpl_str_start
	round1 := ['\\', '\\\\', r"'", "\\'", r'@', r'$']
	round2 := [r'$$', r'\@', r'.$', r'.@']
	mut rline := line.replace_each(round1).replace_each(round2)

	if rline.ends_with('\\') {
		rline = rline[0..rline.len - 2] + 'ssseee'
	}

	return rline
}

fn execute_template(template_file string, out_file string, context map[string]Any) ! {
	mut lines := os.read_lines(template_file) or { return err }
	mut f := os.create(out_file) or { return err }

	for l in lines {
		if l.contains('@if ') {
			
			continue
		}

		f.writeln(insert_template_code(l)) or { return err }
	}
}
