module tmpl

fn test_main() {
	mut context := map[string]Any
	
	context = {
		'name' : 'Peter'
		'age' : 25
		'numbers' : [Any(1), 2, 3]
	}

	a := 
'name: @name

age: @age

numbers: @numbers

@for number in numbers
  @number
@end

@include READMEe.md'

	b := template_string(a, context) or {
		panic(err)
	}

	assert b.split_into_lines()[0] == 'name: Peter'
	assert b.split_into_lines()[2] == 'age: 25'
	assert b.split_into_lines()[4] == 'numbers: [1, 2, 3]'
}