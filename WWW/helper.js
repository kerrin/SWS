function submit_form(form)
{
   // Simple submit for the moment
   document.forms[form].submit();
   return false;
}

function set_value(form,key,value)
{
   // Simple submit for the moment
   document.forms[form].elements[key].value = value;
   return false;
}

function focus_form(form, form_element)
{
   // Set focus to the form element requested
   var found_element;
   if (navigator.appName == 'Netscape')
   {
      found_element = document.forms[form].elements[form_element];
   } else {
      var field = document.forms[form];
      for (i = 0; i < field.length; i++) 
      {
         found_element = field.elements[i];
         if (found_element.name == form_element)
         {
            break;
         }
      }
   }
   if(found_element)
   {
      found_element.focus();
   }
   return false;
}

var remember_form;
var remember_element;
function refocus_form_on_enter(form, form_element)
{
   // Check for Netscape as it deals with enter differently to ie
   var form_handle = document.forms[form];
   if (navigator.appName == 'Netscape')
   {
      // Use this handler
      window.onkeypress = netscape_keypress_refocus;
      window.captureEvents(Event.KEYPRESS);
      remember_form = form_handle;
      remember_element = form_element;
   } else if (window.event.keyCode == 13) {
      // Return has been detected, so submit the form
      var element = form_handle.elements[form_element];
      element.focus();
   }
   return true;
}

function netscape_keypress_refocus(pressed_key)
{
   // Check what was pressed
   if (pressed_key.which == 13)
   {
      var element = remember_form.elements[remember_element];
      element.focus();
   }
}
function submit_form_on_enter(form)
{
   // Check for Netscape as it deals with enter differently to ie
   var form_handle = document.forms[form];
   if (navigator.appName == 'Netscape')
   {
      // Use this handler
      window.onkeypress = netscape_keypress_submit;
      window.captureEvents(Event.KEYPRESS);
      remember_form = form_handle;
   } else if (window.event.keyCode == 13)
   {
      // Return has been detected, so submit the form
      form_handle.submit();
   }
   return true;
}

function netscape_keypress_submit(pressed_key)
{
   // Check what was pressed
   if (pressed_key.which == 13)
   {
      // Return has been detected, so submit the form
      remember_form.submit();
   }
}
