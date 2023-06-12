var req = new XMLHttpRequest();
req.open("GET",
         'http://172.23.71.47:8081/jasperserver/rest_v2/reports/reports/interactive/CustomersReport.pdf'
         + '?j_username=jasperadmin&j_password=jasperadmin'
         , true);
req.responseType = "blob";

req.onload = function (event) {
  var blob = req.response;
  console.log(blob.size);
  var link=document.createElement('a');
  link.href=window.URL.createObjectURL(blob);
  link.download="employee_list_" + apex.item("APP_USER").getValue()+ new Date() + ".pdf";

// Attach the <a> element to DOM and trigger download
  document.body.appendChild(link);
  link.click();

// Clean up the <a> element after download is initiated
  document.body.removeChild(link);

};

req.send();
