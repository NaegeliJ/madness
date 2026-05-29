$(function() {
  new ClipboardJS('pre > code', {
    target: function(trigger) {
      return trigger.parentElement;
    }
  });
})
