import os
import term

fn main() {
	execute_template('use.tmpl', 'out.tmpl', {
		'bool_value': true
		'hello!':     [Any(2), 5, 6, 4]
	}) or {
		eprintln('$err')
		exit(1)
	}
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

type Any = []Any | bool | f64 | int | map[string]Any | string

struct Loc {
	row int
	col int
}

struct TemplateNone {
	loc Loc
	start int = -1
}

struct TemplateFor {
	loc Loc
	start       int
	inner_name  string
	inner_array string
}

struct TemplateIf {
	loc Loc
	start int
	value bool
}

interface TemplateNode {
	loc Loc
	start int
}

fn fail_message(filename string, line int, col int, err string) string {
	return term.red(term.bold('$filename:$line:$col: ')) + err
}

fn get_value(value string, context &map[string]Any) ?Any {
	v := (*context)[value] or { return none }

	// TODO: support inner.value for context['inner']['value']

	return v
}

fn error_string(err string, filename string, loc Loc) string {
	return '(template error) ' + term.red(term.bold('$filename:$loc.row:$loc.col: ')) +
				err
}

/* fn format_line(line string, context &map[string]Any) string {

} */

fn execute_template(template_file string, out_file string, _context map[string]Any) ! {
	mut context := _context.clone()
	mut lines := os.read_lines(template_file) or { return err }
	mut f := os.create(out_file) or { return err }

	mut tmpl_context := TemplateNode(TemplateNone{})

	for idx, l in lines {
		start, end := l.trim_indexes(' \n\t\v\f\r')
		s := l.substr(start, end)

		loc := Loc{
			row: idx + 1
			col: start + 1
		}
		tmpl_error := fn [template_file, loc] (err string) string {
			return error_string(err, template_file, loc)
		}

		match true {
			s.starts_with('@if ') {
				if tmpl_context !is TemplateNone {
					return error(tmpl_error('nesting of template statements are not allowed'))
				}
				value := get_value(s[4..], &context) or {
					return error(tmpl_error('value not located in template context'))
				}
				if value is bool {
					tmpl_context = TemplateIf{
						loc: loc
						start: idx
						value: value
					}
				} else {
					return error(tmpl_error('value is not a boolean'))
				}
				continue
			}
			s.starts_with('@for ') {
				if tmpl_context !is TemplateNone {
					return error(tmpl_error('nesting of template statements are not allowed'))
				}
				args := s[5..].split(' ')
				if args.len != 3 || args[1] != 'in' {
					return error(tmpl_error('for loop must be in array style, `@for v in values`'))
				}
				array_value := get_value(args[2], &context) or {
					return error(tmpl_error('array value not located in template context'))
				}
				if array_value is []Any {
					tmpl_context = TemplateFor{
						loc: loc
						start: idx
						inner_name: args[0]
						inner_array: args[2]
					}
				} else {
					return error(tmpl_error('array value is not an array'))
				}
				continue
			}
			s.starts_with('@end') {
				match mut tmpl_context {
					TemplateIf {
						if tmpl_context.value as bool {
							for i := tmpl_context.start + 1; i < idx; i++ {
								f.writeln(insert_template_code(lines[i])) or { return err }
							}
						}
					}
					TemplateFor {

					}
					TemplateNone {
						return error(tmpl_error('not inside a template statement'))
					}
					else {
						assert false, 'unreachable'
					}
				}
				tmpl_context = TemplateNone{}
				continue
			}
			else {
				if tmpl_context !is TemplateNone {
					continue
				}
			}
		}

		f.writeln(insert_template_code(l)) or { return err }
	}

	if tmpl_context !is TemplateNone {
		return error(error_string('unhandled template statement', template_file, tmpl_context.loc))
	}
}
