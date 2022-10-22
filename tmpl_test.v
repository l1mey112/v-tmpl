fn test_main() {
	mut context := map[string]Any
	
	context = {
		'name' : 'Peter'
		'age' : 25
		'numbers' : [Any(1), 2, 3]
	}

	a := 
'name: @_name

age: @_age

numbers: @_numbers

@for number in numbers
  @number
@end'

	template_string(a, context) or {
		panic(err)
	}
}