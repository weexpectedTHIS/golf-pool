$(document).ready(function(){
  // GLOBAL PREVENTION OF HREF PROPOGATION FOR JS LINKS
  $('a[href^=#], a[data-remote=true]').click(function(e){ e.preventDefault(); });

  $('#update').click(function(){
    var form = $('<form action="/" method="post"><input type="hidden" name="update" value="1" /></form>');
    $('body').prepend(form);
    form.submit();
  });
  $('#change_brackets_link').click(function(e){
    e.preventDefault();
    $('#change_brackets_form').dialog({minHeight: 550, minWidth: 650});
  });
});
