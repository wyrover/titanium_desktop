describe("php tests",
{
	test_bind_types: function()
	{
		value_of(window.bind_types).should_be_function();
		
		var obj = {};
		window.bind_types(obj);
		
		
		value_of(obj.number).should_be(1);
		value_of(obj.str).should_be("string");
		value_of(obj.list).should_match_array([1,2,3,4]);
		value_of(obj.hash).should_be_array();
		value_of(obj.hash.a).should_be('b');
		
		value_of(obj.object).should_be_object();
		value_of(obj.object.testmethod).should_be_function();
		
		obj.object.testmethod();
		value_of(obj.object.value).should_be(100);
	},
	
	test_inline: function()
	{
		value_of(window.inline_test_result).should_be('A');
	},
	
	test_external_file: function()
	{
		value_of(window.external_test_result).should_be('A');
	},
	
	test_window_global_from_php: function()
	{
		// test to make sure that we can access a function defined
		// in normal javascript block from within ruby 
		value_of(window.test_window_global_result).should_be('you suck ass');
	},
	
	test_document_title_from_php: function()
	{
		value_of(window.test_document_title_result).should_be('PHP');
	},
	test_js_types: function()
	{
		value_of(test_js_type_string('1')).should_be_true();
		value_of(test_js_type_float(123)).should_be_true();
		value_of(test_js_type_float(0)).should_be_true();
		value_of(test_js_type_float(10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000)).should_be_true();
		value_of(test_js_type_float(3.14)).should_be_true();
		value_of(test_js_type_object(function() { }, 'PHPKMethod')).should_be_true();
		value_of(test_js_type_object([1,2,3], 'PHPKList')).should_be_true();
		value_of(test_js_klist_elements([1,2,3])).should_be_true();
		value_of(test_js_type_object({'a1':'sauce'}, 'PHPKObject')).should_be_true();
		value_of(test_js_type_object({}, 'PHPKObject')).should_be_true();
		value_of(test_js_type_null(null)).should_be_true();
		value_of(test_js_type_null(undefined)).should_be_true();
		value_of(test_js_type_false_bool(false)).should_be_true();
		value_of(test_js_type_true_bool(true)).should_be_true();
	},
	test_method_arguments: function()
	{
		var obj = {};
		window.bind_types(obj);

		obj.object.testmethod();
		value_of(obj.object.value).should_be(100);

		obj.object.testmethodonearg(555);
		value_of(obj.object.value).should_be(555);

		obj.object.testmethodtwoargs(111, 222);
		value_of(obj.object.value).should_be(333);
	},
	test_calling_method_props_obj: function()
	{
		var obj = {};
		var fun2  = function() { return 1; };
		var funarg  = function(arg) { return arg; };
		obj.f = fun2;
		obj.f2 = funarg
		value_of(test_call_method_prop(obj)).should_be(1);
		value_of(test_call_method_prop_with_arg(obj,"toots")).should_be("toots");
	},
	test_calling_method_props_array: function()
	{
		var arr = [1, 2, 3];
		var fun2  = function() { return 1; };
		var funarg  = function(arg) { return arg; };
		arr.f = fun2;
		arr.f2 = funarg
		value_of(test_call_method_prop(arr)).should_be(1);
		value_of(test_call_method_prop_with_arg(arr, "toots")).should_be("toots");
	},
	test_calling_method_props_method: function()
	{
		var fun = function() { return 0; };
		var funarg  = function(arg) { return arg; };
		var fun2  = function() { return 1; };
		fun.f = fun2;
		fun.f2 = funarg
		value_of(test_call_method_prop(fun)).should_be(1);
		value_of(test_call_method_prop_with_arg(fun, "toots")).should_be("toots");
	},
	test_class_visibility: function()
	{
		var hammer = looks_like_a_nail();
		value_of(hammer.publicVariable).should_be("bar");
		value_of(hammer.privateVariable).should_be_undefined();
		value_of(hammer.publicMethod).should_be_function();
		value_of(hammer.publicMethod()).should_be("foo");
		value_of(hammer.privateMethod).should_be_undefined();
	},
	test_modify_array: function()
	{
		var myarray = [1, 2, 3];
		php_modify_array(myarray);
		value_of(myarray[0]).should_be(4);
		value_of(myarray[1]).should_be(5);
		value_of(myarray[2]).should_be(6);
		value_of(myarray[3]).should_be(7);
	},
	test_preprocess_as_async: function(callback)
	{ 
		var w = Titanium.UI.currentWindow.createWindow('app://test.php?param1=1&param2=2');
		var timer = 0;
		w.addEventListener(Titanium.PAGE_LOADED, function(event) {
			clearTimeout(timer);
			try
			{
				function domValue(id) { return w.getDOMWindow().document.getElementById(id).innerHTML; }
				value_of(domValue("a")).should_be("101");
				value_of(domValue("request-uri")).should_be("/test.php?param1=1&amp;param2=2");
				value_of(domValue("script-name")).should_be("/test.php");
				value_of(domValue("param1")).should_be(1);
				value_of(domValue("param2")).should_be(2);
				
				callback.passed();
			}
			catch(e)
			{
				callback.failed(e);
			}
		});
		timer = setTimeout(function() {
			callback.failed("Timed out waiting for preprocess");
		}, 3000);
		w.open();
	},
	test_across_script_tags: function()
	{
		var result = across_script_tags();
		value_of(result).should_be(24);
	},
	test_global_variable_persistence: function()
	{
		var result = get_substance();
		value_of(result).should_be("donkey poop");
	},
	test_deep_global_variable_persistence: function()
	{
		modify_substance();
		var result = get_substance();
		value_of(result).should_be("ninja food");
	},
	test_deep_global_variable_isolation_as_async: function(callback)
	{
		Titanium.page_two_loaded = function()
		{
			// Modify the main page version of '$substance'
			modify_substance();
			var result = Titanium.get_page_two_substance();
			if (result == "page two")
			{
				callback.passed();
			}
			else
			{
				callback.failed('$substance should have been "page two" was: ' 
					+ result);
			}
		}

		var w = Titanium.UI.getCurrentWindow().createWindow('app://another.html');
		w.open();

		setTimeout(function()
		{
			callback.failed("Test timed out");
		}, 2000);
	},
	test_anonymous_functions: function(callback)
	{
		var anon = php_get_anonymous_function();
		var result = anon();
		value_of(result).should_be("blueberry");

		var anon2 = php_get_anonymous_function_one_arg();
		result = anon2("dino");
		value_of(result).should_be("DINO");

		var anon3 = php_get_anonymous_function_two_args();
		result = anon3("dino", "bones");
		value_of(result).should_be("DINOBONES");
	},
	test_titanium_object_access: function(callback)
	{
		var result = get_resources_directory_via_php().toString();
		value_of(result).should_be_string();
		value_of(result.length).should_be_number();
	},
	test_include_contains_resources_directory: function()
	{
		// Test that files in the Resources directory
		//  are on the include path.
		var include_path = get_include_path();
		var res_dir = Titanium.API.getApplication().getResourcesPath();
		value_of(include_path.indexOf(res_dir) != -1).should_be_true();
	},
	test_include_access: function()
	{
		value_of(test_include()).should_be("yes");
	},
	test_cased_function_names: function()
	{
		value_of(CamelCaseFunctionOne()).should_be("uno");
		value_of(camelCaseFunctionTwo()).should_be("dos");
		value_of(ALLCAPSFUNCTION()).should_be("tres");
	},
	test_mysql: function()
	{
		value_of(php_test_mysql()).should_be_true();
	},
	test_curl: function()
	{
		value_of(php_test_curl()).should_be_true();
	},
	test_array_getArrayCopy: function()
	{
		var arr = php_test_array_getArrayCopy([1, 2, 3, 4]);
		value_of(arr.length).should_be(4);
		value_of(arr[0]).should_be(1);
		value_of(arr[1]).should_be(2);
		value_of(arr[2]).should_be(3);
		value_of(arr[3]).should_be(4);
	}
});
