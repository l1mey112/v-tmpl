# v-tmpl

An implementation of the compile time template system for generic use. Striving to be compatible with and to extend the existing V `$tmpl()` system.

This is highly experimental, most features are not properly implemented and there are some edge cases. Be warned.

PRs welcome!

# Basic Usage

```v
import tmpl

fn main() {
	mut context := map[string]tmpl.Any
	
	context = {
		'name' : 'Peter'
		'age' : 25
		'numbers' : [Any(1), 2, 3]
	}

	a := 
"name: @name

age: @age

numbers: @numbers

@for number in numbers
  @number
@end"

	b := tmpl.template_string(a, context) or {
		panic(err)
	}

	assert b.split_into_lines()[0] == "name: Peter"
	assert b.split_into_lines()[2] == "age: 25"
	assert b.split_into_lines()[4] == "numbers: [1, 2, 3]"
}
```

```
(template error) file.tmpl:9:1: value not found in template context
(template error) file.tmpl:7:1: unhandled template statement
(template error) file.tmpl:11:1: file to include could not be opened
```