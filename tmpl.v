module tmpl

import os
import term
import strings

pub type Any = []Any | bool | f64 | int | map[string]Any | string

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
	inner_array []Any
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

fn get_value(value string, context &map[string]Any) ?Any {
	v := (*context)[value] or { return none }

	// TODO: support inner.value for context['inner']['value']

	return v
}

pub fn error_string(err string, filename string, loc Loc) string {
	return '(template error) ' + term.red(term.bold('$filename:$loc.row:$loc.col: ')) +
				err
}

fn (v Any) str() string {
    match v {
        bool, f64, int, string, []Any, map[string]Any { return v.str() }
    }
}

fn format_line(line string, mut builder strings.Builder, context &map[string]Any) ! {
	a := line.split(' ')
	for idx, l in a {
		if l.len == 0 {
			continue
		}
		if l[0] == `@` {
			v := get_value(l[1..], context) or {
				return error('')
			}
			builder.write_string('${v}')
		} else {
			builder.write_string('$l')
		}
		if idx != a.len - 1 {
			builder.write_u8(` `)
		}
	}
}

pub fn template_string(template_string string, context map[string]Any) !string {
	return execute_template(template_string, '_', context)!
}

pub fn template_file(template_file string, out_file string, context map[string]Any) ! {
	fstring := os.read_file(template_file)!
	ostring := execute_template(fstring, template_file, context)!
	os.write_file(out_file, ostring)!
}

pub fn execute_template(template_string string, template_file string, _context map[string]Any) !string {
	mut context := _context.clone()

	lines := template_string.split_into_lines()
	mut f := strings.new_builder(template_string.len)

	mut tmpl_context := TemplateNode(TemplateNone{})
	mut line_builder := strings.new_builder(80)

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

		/* TODO: 
		s.contains('@if ') {
			pos := line.index('@if') or { continue }
			source.writeln(line[..pos])
			// write the rest of the line,
			// then handle @if
		} */

		match true {
			s.starts_with('@if ') {
				if tmpl_context !is TemplateNone {
					return error(tmpl_error('nesting of template statements are not allowed'))
				}
				value := get_value(s[4..], &context) or {
					return error(tmpl_error('value not found in template context'))
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
					return error(tmpl_error('array value not found in template context'))
				}
				if array_value is []Any {
					tmpl_context = TemplateFor{
						loc: loc
						start: idx
						inner_name: args[0]
						inner_array: array_value
					}
				} else {
					return error(tmpl_error('array value is not an array'))
				}
				continue
			}
			s.starts_with('@include ') {
				file_name := s[9..]
				fp := os.read_file(file_name) or {
					return error(tmpl_error('file to include could not be opened'))
				}
				f.write_string(fp)
				continue
			}
			s.starts_with('@end') {
				match mut tmpl_context {
					TemplateIf {
						if tmpl_context.value as bool {
							for i := tmpl_context.start + 1; i < idx; i++ {
								format_line(lines[i], mut line_builder, &context) or {
									return error(tmpl_error('value not found in template context'))
								}
								f.writeln(line_builder.str())
							}
						}
					}
					TemplateFor {
						// shadow the variable
						mut is_shadowed := false
						a := context[tmpl_context.inner_name] or {
							is_shadowed = true
							-1
						}
						for value in tmpl_context.inner_array {
							context[tmpl_context.inner_name] = value
							for i := tmpl_context.start + 1; i < idx; i++ {
								format_line(lines[i], mut line_builder, &context) or {
									return error(tmpl_error('value not found in template context'))
								}
								f.writeln(line_builder.str())
							}
						}
						if is_shadowed {
							context[tmpl_context.inner_name] = a
						}
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
		format_line(l, mut line_builder, &context) or {
			return error(tmpl_error('value not found in template context'))
		}
		f.writeln(line_builder.str())
	}

	if tmpl_context !is TemplateNone {
		return error(error_string('unhandled template statement', template_file, tmpl_context.loc))
	}

	return f.str()
}
