this["JST"] = this["JST"] || {};

this["JST"]["resources/templates/configuration_view.hbs"] = Handlebars.template(function (Handlebars,depth0,helpers,partials,data) {
  this.compilerInfo = [2,'>= 1.0.0-rc.3'];
helpers = helpers || Handlebars.helpers; data = data || {};
  var buffer = "", stack1, functionType="function", escapeExpression=this.escapeExpression;


  buffer += "<table class=\"table table-striped\">\n    <tr>\n        <th>Option</th>\n        <th>Value</th>\n    </tr>\n    <tr>\n        <td>beanstalk_url</td>\n        <td>";
  if (stack1 = helpers.beanstalk_url) { stack1 = stack1.call(depth0, {hash:{},data:data}); }
  else { stack1 = depth0.beanstalk_url; stack1 = typeof stack1 === functionType ? stack1.apply(depth0) : stack1; }
  buffer += escapeExpression(stack1)
    + "</td>\n    </tr>\n    <tr>\n        <td>tube_namespace</td>\n        <td>";
  if (stack1 = helpers.tube_namespace) { stack1 = stack1.call(depth0, {hash:{},data:data}); }
  else { stack1 = depth0.tube_namespace; stack1 = typeof stack1 === functionType ? stack1.apply(depth0) : stack1; }
  buffer += escapeExpression(stack1)
    + "</td>\n    </tr>\n    <tr>\n        <td>default_priority</td>\n        <td>";
  if (stack1 = helpers.default_priority) { stack1 = stack1.call(depth0, {hash:{},data:data}); }
  else { stack1 = depth0.default_priority; stack1 = typeof stack1 === functionType ? stack1.apply(depth0) : stack1; }
  buffer += escapeExpression(stack1)
    + "</td>\n    </tr>\n    <tr>\n        <td>respond_timeout</td>\n        <td>";
  if (stack1 = helpers.respond_timeout) { stack1 = stack1.call(depth0, {hash:{},data:data}); }
  else { stack1 = depth0.respond_timeout; stack1 = typeof stack1 === functionType ? stack1.apply(depth0) : stack1; }
  buffer += escapeExpression(stack1)
    + "</td>\n    </tr>\n    <tr>\n        <td>max_job_retries</td>\n        <td>";
  if (stack1 = helpers.max_job_retries) { stack1 = stack1.call(depth0, {hash:{},data:data}); }
  else { stack1 = depth0.max_job_retries; stack1 = typeof stack1 === functionType ? stack1.apply(depth0) : stack1; }
  buffer += escapeExpression(stack1)
    + "</td>\n    </tr>\n    <tr>\n        <td>retry_delay</td>\n        <td>";
  if (stack1 = helpers.retry_delay) { stack1 = stack1.call(depth0, {hash:{},data:data}); }
  else { stack1 = depth0.retry_delay; stack1 = typeof stack1 === functionType ? stack1.apply(depth0) : stack1; }
  buffer += escapeExpression(stack1)
    + "</td>\n    </tr>\n    <tr>\n        <td>default_worker</td>\n        <td>";
  if (stack1 = helpers.default_worker) { stack1 = stack1.call(depth0, {hash:{},data:data}); }
  else { stack1 = depth0.default_worker; stack1 = typeof stack1 === functionType ? stack1.apply(depth0) : stack1; }
  buffer += escapeExpression(stack1)
    + "</td>\n    </tr>\n</table>";
  return buffer;
  });

this["JST"]["resources/templates/monitoring_view.hbs"] = Handlebars.template(function (Handlebars,depth0,helpers,partials,data) {
  this.compilerInfo = [2,'>= 1.0.0-rc.3'];
helpers = helpers || Handlebars.helpers; data = data || {};
  


  return "MONITORING VIEW";
  });