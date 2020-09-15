// Author:  Ryan Wilcox
// Description: Frontend componit of the admin website interface for the IPad app.

//###############################################################################################################################################################
$(document).ready(function() {
	// Setup the menu bar
	$("#mainBar").menubar({
		position: {
			within: $("#menubarDiv").add(window).first()
		},
		// select: select
		select: function (event, ui) {
			$('.selected', this).removeClass('selected');
			ui.item.addClass('selected');
		}
	});
	$('#mainBar').find('a[href="'+ window.location.pathname +'"]').addClass('ui-state-active');

	updateClock();
	setInterval('updateClock()', 1000); // refresh the clock every 1 second
});

//###############################################################################################################################################################
// Used for the Station/Metar Association page
function stationList(dbType) {
	console.log("info: siteSearch");
	
	var data = {};
	data['stationID'] = configInt.cache.stationID.val();
	data['xmlName'] = configInt.cache.xmlName.val();
	if(dbType != 'metar') {
		data['regionID'] = configInt.cache.regionID.val();
	}
	data['vRegion'] = configInt.cache.vRegion.val();
	
	var callback = function(response, textStatus, xhr) { // Default call back func to set the input
		configInt.cache.stationDiv.html('<select id="stationList" title="Station List" multiple="multiple" size="10" style="width:550px; height:300px;"></select>');
		for(var item in response) {	
			$('#stationList').append('<option selected="selected" value='+response[item]['stn_id']+'>'+response[item]['xml_target_name']+ ' (' +response[item]['station_name']+ ')</option>');
		};

		$('#stationList').multiselect();
		configInt.cache.mapStations.attr('disabled', false);
		configInt.cache.unmapStations.attr('disabled', false);
	};
	
	
	URLstring = '/get/stationList';
	if(dbType == 'metar') {
		URLstring = '/getMetar/stationList';
	} 

	var siteSearchOptions = {};
	siteSearchOptions['url'] = configInt.settings.baseURL + URLstring;
	siteSearchOptions['data'] = data;
	siteSearchOptions['success'] = callback;

	return restCall(siteSearchOptions);
	
	return;
}

function virtualRegionMap(dbType) {
	console.log("info: virtualRegionMap");
	
	var data = {};
	data['stationList'] = $('#stationList').val();
	data['vRegionList'] = configInt.cache.vRegionList.val();
	data['addedBy'] = configInt.cache.addedBy.val();
	data['description'] = configInt.cache.addDescription.val();
	
	var callback = function(response, textStatus, xhr) { // Default call back func to set the input
		configInt.cache.mapMessage.html(response.msg);
		resetPage();
	};
	
	URLstring = '/set/virtualRegionMap';
	if(dbType == 'metar') {
		URLstring = '/set/metarvirtualRegionMap';
	} 

	var siteSearchOptions = {};
	siteSearchOptions['url'] = configInt.settings.baseURL + URLstring;
	siteSearchOptions['data'] = data;
	siteSearchOptions['success'] = callback;

	return restCall(siteSearchOptions);
	
	return;
}

function deleteVirtualRegionMap(dbType) {
	console.log("info: deleteVirtualRegionMap");
	
	var data = {};
	data['stationList'] = $('#stationList').val();
	data['vRegion'] = $('#vRegionList').val();
	data['addedBy'] = configInt.cache.addedBy.val();
	data['description'] = configInt.cache.addDescription.val();
	
	var callback = function(response, textStatus, xhr) { // Default call back func to set the input
		configInt.cache.mapMessage.html(response.msg);
		resetPage();
	};

	URLstring = '/delete/virtualRegionMap';
	if(dbType == 'metar') {
		URLstring = '/delete/metarvirtualRegionMap';
	} 

	var siteSearchOptions = {};
	siteSearchOptions['url'] = configInt.settings.baseURL + URLstring;
	siteSearchOptions['data'] = data;
	siteSearchOptions['success'] = callback;

	return restCall(siteSearchOptions);
	
	return;
}

//###############################################################################################
// Used for user page

function userAdd() {
	configInt.cache.addSubmit.prop("disabled", true);

	var callback = function(response, textStatus, xhr) { // Default call back func to set the input
		if(xhr.status != 200) {
			msg = 'Error: ('+ xhr +'). You might want to ask someone to look in the web logs for the details of this error. ' +
					'Please give the admin the time of this error so they can find the matching info in the logs.'
			
			console.log(xhr.statusText);
			alert(msg);
		} else if(xhr.responseJSON.msg.toLowerCase().indexOf('success') >= 0) {
			configInt.cache.addMessage.text(xhr.responseJSON.msg);
			$("table").trigger("update");
			drawPage();
		} else if(xhr.responseJSON.msg.toLowerCase().indexOf('warning') >= 0) {
			configInt.cache.addMessage.text(xhr.responseJSON.msg);
		} else {
			msg = 'Unknow error: ('+ xhr.status +')  '+ xhr.statusText +' You might want to ask someone to look in the web logs for the details of this error. ' +
			'Please give the admin the time of this error so they can find the matching info in the logs.'

			console.log('Unknow error: ('+ xhr.status +')  '+ xhr.statusText);
			alert(msg);
		}

		configInt.cache.addSubmit.prop("disabled", false);
	}

	var data = {};
	data['username'] = configInt.cache.addUsername.val();
	data['roles'] = $("#addRole").selectList().val();
	data['password'] = configInt.cache.addPassword.val();
	data['addedBy'] = configInt.cache.addedBy.val();
	data['description'] = configInt.cache.addDescription.val();
	
	for (var variable in data) {
		if(data[variable] == '' ) {
			var msg = "Missing needed data";
			console.log(msg);
			return 'Error: '+msg;
		}
	}
	
	var options = {};
	options['url'] = configInt.settings.baseURL + '/user/add';
	options['data'] = data;
	options['success'] = callback;
	options['error'] = callback;

	restCall(options);
	
	return 'success';
}

function userModifyRole() {
	configInt.cache.modifySubmit.prop("disabled", true);

	var callback = function(response, textStatus, xhr) { // Default call back func to set the input
		if(xhr.status != 200) {
			msg = 'Error: ('+ xhr +'). You might want to ask someone to look in the web logs for the details of this error. ' +
					'Please give the admin the time of this error so they can find the matching info in the logs.'
			
			console.log(xhr.statusText);
			alert(msg);
		} else if(xhr.responseJSON.msg.toLowerCase().indexOf('success') >= 0) {
			configInt.cache.modifyMessage.text(xhr.responseJSON.msg);
			$("table").trigger("update");
			drawPage();
		} else {
			msg = 'Unknow error: ('+ xhr.status +')  '+ xhr.statusText +' You might want to ask someone to look in the web logs for the details of this error. ' +
			'Please give the admin the time of this error so they can find the matching info in the logs.'

			console.log('Unknow error: ('+ xhr.status +')  '+ xhr.statusText);
			alert(msg);
		}

		configInt.cache.modifySubmit.prop("disabled", false);
	}

	var data = {};
	data['username'] = configInt.cache.modifyUsername.val();
	data['roles'] = $("#modifyRole").selectList().val();
	
	for (var variable in data) {
		console.log(variable);
		if(data[variable] == '') {
			var msg = "Missing needed data";
			console.log(msg);
			return 'Error: '+msg;
		}
	}
	
	var options = {};
	options['url'] = configInt.settings.baseURL + '/user/setRole';
	options['data'] = data;
	options['success'] = callback;
	options['error'] = callback;

	restCall(options);
	
	return 'success';
}

function userSetPassword() {
	configInt.cache.passwordSubmit.prop("disabled", true);

	var callback = function(response, textStatus, xhr) { // Default call back func to set the input
		if(xhr.status != 200) {
			msg = 'Error: ('+ xhr +'). You might want to ask someone to look in the web logs for the details of this error. ' +
					'Please give the admin the time of this error so they can find the matching info in the logs.'
			
			console.log(xhr.statusText);
			alert(msg);
		} else if(xhr.responseJSON.msg.toLowerCase().indexOf('success') >= 0) {
			configInt.cache.passwordMessage.text(xhr.responseJSON.msg);
			drawPage();
		} else {
			msg = 'Unknow error: ('+ xhr.status +')  '+ xhr.statusText +' You might want to ask someone to look in the web logs for the details of this error. ' +
			'Please give the admin the time of this error so they can find the matching info in the logs.'

			console.log('Unknow error: ('+ xhr.status +')  '+ xhr.statusText);
			alert(msg);
		}

		configInt.cache.passwordSubmit.prop("disabled", false);
	}

	var data = {};
	data['username'] = configInt.cache.changeUsername.val();
	data['password'] = configInt.cache.changePassword.val();
	
	for (var variable in data) {
		console.log(variable);
		if(data[variable] == '') {
			var msg = "Missing needed data";
			console.log(msg);
			return 'Error: '+msg;
		}
	}
	
	var options = {};
	options['url'] = configInt.settings.baseURL + '/user/setPassword';
	options['data'] = data;
	options['success'] = callback;
	options['error'] = callback;

	restCall(options);
	
	return 'success';
}

function userDelete() {
	var x;
	var r=confirm("Are you sure you want to delete this user?");
	if (r != true) {
		alert("Canceled deletion!");
		return 'canceled';
	}

	configInt.cache.deleteSubmit.prop("disabled", true);

	var callback = function(response, textStatus, xhr) { // Default call back func to set the input
		if(xhr.status != 200) {
			msg = 'Error: ('+ xhr +'). You might want to ask someone to look in the web logs for the details of this error. ' +
					'Please give the admin the time of this error so they can find the matching info in the logs.'
			
			console.log(xhr.statusText);
			alert(msg);
		} else if(xhr.responseJSON.msg.toLowerCase().indexOf('success') >= 0) {
			configInt.cache.deleteMessage.text(xhr.responseJSON.msg);
			$("table").trigger("update");
			drawPage();
		} else {
			msg = 'Unknow error: ('+ xhr.status +')  '+ xhr.statusText +' You might want to ask someone to look in the web logs for the details of this error. ' +
			'Please give the admin the time of this error so they can find the matching info in the logs.'

			console.log('Unknow error: ('+ xhr.status +')  '+ xhr.statusText);
			alert(msg);
		}

		configInt.cache.deleteSubmit.prop("disabled", false);
	}

	var data = {};
	data['userID'] = configInt.cache.deleteUser.val();
	
	for (var variable in data) {
		console.log(variable);
		if(typeof data[variable] == 'undefined') {
			var msg = "Missing needed data";
			console.log(msg);
			return 'Error: '+msg;
		}
	}
	
	var options = {};
	options['url'] = configInt.settings.baseURL + '/user/delete';
	options['data'] = data;
	options['success'] = callback;
	options['error'] = callback;

	restCall(options);
	
	return 'success';
}

//###############################################################################################
// Used for the Roles page

// function createRoleTable() {
// 	console.log("info: siteSearch");
	
// 	var data = {};
// 	createTableDataSimple(configInt.cache.roleTable,data,'/role/listTable',[[0,0]]);
	
// 	return;
// }

function roleAdd() {
	console.log("roleAdd was called");
	configInt.cache.addSubmit.prop("disabled", true);

	var callback = function(response, textStatus, xhr) { // Default call back func to set the input
		if(xhr.status != 200) {
			msg = 'Error: ('+ xhr.statusText +'). You might want to ask someone to look in the web logs for the details of this error. ' +
					'Please give the admin the time of this error so they can find the matching info in the logs.'
			
			console.log(xhr.statusText);
			alert(msg);
		} else if(response.msg.toLowerCase().indexOf('success') >= 0) {
			configInt.cache.addMessage.text(xhr.responseJSON.msg);
			$("table").trigger("update");
			drawPage();
		} else if(xhr.responseJSON.msg.toLowerCase().indexOf('warning') >= 0) {
			configInt.cache.addMessage.text(xhr.responseJSON.msg);
		} else {
			msg = 'Unknow error: ('+ xhr.status +')  '+ xhr.statusText +' You might want to ask someone to look in the web logs for the details of this error. ' +
			'Please give the admin the time of this error so they can find the matching info in the logs.'

			console.log('Unknow error: ('+ xhr.status +')  '+ xhr.statusText);
			alert(msg);
		}

		configInt.cache.addSubmit.prop("disabled", false);
		return response.msg;
	}

	var data = {};
	data['role'] = configInt.cache.addRole.val();
	data['addedBy'] = configInt.cache.addedBy.val();
	data['countryCode'] = configInt.cache.addCountryCode.val();
	data['description'] = configInt.cache.addDescription.val();
	data['metarData'] = configInt.cache.addmetarData.is(':checked') ? 1 : 0;
	data['ltgData'] = configInt.cache.addltgData.is(':checked') ? 1 : 0;
	data['graphData'] = configInt.cache.addgraphData.is(':checked') ? 1 : 0;
	data['tickerData'] = configInt.cache.addtickerData.is(':checked') ? 1 : 0;
	
	for (var variable in data) {
		if(isUndefined(data[variable])) {
			var msg = "Missing needed data";
			console.log(msg);
			return 'Error: '+msg;
		}
	}
	
	var options = {};
	options['url'] = configInt.settings.baseURL + '/role/add';
	options['data'] = data;
	options['success'] = callback;
	options['error'] = callback;

	restCall(options);
	
	return;
}

function roleRename() {
	console.log("roleRename was called");
	configInt.cache.renameSubmit.prop("disabled", true);

	var callback = function(response, textStatus, xhr) { // Default call back func to set the input
		if(xhr.status != 200) {
			msg = 'Error: ('+ xhr.statusText +'). You might want to ask someone to look in the web logs for the details of this error. ' +
					'Please give the admin the time of this error so they can find the matching info in the logs.'
			
			console.log(xhr.statusText);
			alert(msg);
		} else if(response.msg.toLowerCase().indexOf('success') >= 0) {
			configInt.cache.renameMessage.text(xhr.responseJSON.msg);
			$("table").trigger("update");
			drawPage();
		} else if(xhr.responseJSON.msg.toLowerCase().indexOf('warning') >= 0) {
			configInt.cache.renameMessage.text(xhr.responseJSON.msg);
		} else {
			msg = 'Unknow error: ('+ xhr.status +')  '+ xhr.statusText +' You might want to ask someone to look in the web logs for the details of this error. ' +
			'Please give the admin the time of this error so they can find the matching info in the logs.'

			console.log('Unknow error: ('+ xhr.status +')  '+ xhr.statusText);
			alert(msg);
		}

		configInt.cache.renameSubmit.prop("disabled", false);
		return response.msg;
	}

	var data = {};
	data['regionID'] = configInt.cache.regionID.val();
	data['newName'] = configInt.cache.newName.val();
	data['newDescription'] = configInt.cache.newDescription.val();
	
	for (var variable in data) {
		if(isUndefined(data[variable])) {
			var msg = "Missing needed data";
			console.log(msg);
			return 'Error: '+msg;
		}
	}
	
	var options = {};
	options['url'] = configInt.settings.baseURL + '/role/rename';
	options['data'] = data;
	options['success'] = callback;
	options['error'] = callback;

	restCall(options);
	
	return;
}

function roleDelete() {
	configInt.cache.deleteSubmit.prop("disabled", true);
	configInt.cache.deleteMessage.text('');

	var data = {};
	data['roleID'] = configInt.cache.deleteRole.val();

	for (var variable in data) {
		if(data[variable] == '' ) {
			var msg = "Missing needed data";
			console.log(msg);
		
			configInt.cache.deleteMessage.text('Error: '+msg);
			configInt.cache.deleteSubmit.prop("disabled", false);

			return 'Error: '+msg;
		}
	}

	var listCallback = function(response, textStatus, xhr) { // Default call back func to set the input
		if(xhr.status != 200) {
			msg = 'Error: ('+ xhr.statusText +'). You might want to ask someone to look in the web logs for the details of this error. ' +
					'Please give the admin the time of this error so they can find the matching info in the logs.'
			
			console.log(xhr.statusText);
			alert(msg);
		} else if(xhr.responseText.toLowerCase().indexOf('error') < 0) { // if no error
			console.log(response);
			var r=confirm("Are you sure you want to delete this role? The databases currently have the following associations:"
				+"\n AuthDB: "+ response.auth
				+"\n CloudDB: "+ response.cloud
				+"\n MetarDB: "+ response.metar
				);
			if (r != true) {
				configInt.cache.deleteMessage.text('Canceled deletion!');
				configInt.cache.deleteSubmit.prop("disabled", false);
				return 'canceled';
			}
			response.msg = roleDeletePart2();

		} else {
			msg = 'Unknow error: ('+ xhr.status +')  '+ xhr.statusText +' You might want to ask someone to look in the web logs for the details of this error. ' +
			'Please give the admin the time of this error so they can find the matching info in the logs.'

			console.log('Unknow error: ('+ xhr.status +')  '+ xhr.statusText);
			alert(msg);
		}

		$("table").trigger("update");
		drawPage();
		configInt.cache.deleteSubmit.prop("disabled", false);
		return response.msg;
	}

	var listOptions = {};
	listOptions['url'] = configInt.settings.baseURL + '/role/count';
	listOptions['data'] = data;
	listOptions['success'] = listCallback;
	listOptions['error'] = listCallback;


	restCall(listOptions);

	return;
}

function roleDeletePart2() {
	var callback = function(response, textStatus, xhr) { // Default call back func to set the input
		if(xhr.status != 200) {
			msg = 'Error: ('+ xhr.statusText +'). You might want to ask someone to look in the web logs for the details of this error. ' +
					'Please give the admin the time of this error so they can find the matching info in the logs.'
			
			console.log(xhr.statusText);
			alert(msg);
		} else if(xhr.responseText.toLowerCase().indexOf('success') >= 0) {
			configInt.cache.deleteMessage.text('Successfully deleted the role');
			$("table").trigger("update");
			drawPage();
		} else if(xhr.responseJSON.msg.toLowerCase().indexOf('warning') >= 0) {
			configInt.cache.addMessage.text(xhr.responseJSON.msg);
		} else {
			msg = 'Unknow error: ('+ xhr.status +')  '+ xhr.statusText +' You might want to ask someone to look in the web logs for the details of this error. ' +
			'Please give the admin the time of this error so they can find the matching info in the logs.'

			console.log('Unknow error: ('+ xhr.status +')  '+ xhr.statusText);
			alert(msg);
		}

		return response.msg;
	}

	var data = {};
	data['roleID'] = configInt.cache.deleteRole.val();
	
	for (var variable in data) {
		console.log(variable);
		if(typeof data[variable] == 'undefined') {
			var msg = "Missing needed data";
			console.log(msg);
			return 'Error: '+msg;
		}
	}
	
	var options = {};
	options['url'] = configInt.settings.baseURL + '/role/deleteAll';
	options['data'] = data;
	options['success'] = callback;
	options['error'] = callback;

	restCall(options);
	
	return;
}

function setRole() {
	configInt.cache.modifyRoleSubmit.prop("disabled", true);

	var callback = function(response, textStatus, xhr) { // Default call back func to set the input
		if(xhr.status != 200) {
			msg = 'Error: ('+ xhr.statusText +'). You might want to ask someone to look in the web logs for the details of this error. ' +
					'Please give the admin the time of this error so they can find the matching info in the logs.'
			
			console.log(xhr.statusText +'   '+ response.msg);
			alert(msg);
		} else if(xhr.responseText.toLowerCase().indexOf('success') >= 0) {
			configInt.cache.modifyMessage.text(xhr.responseJSON.msg);
		} else {
			msg = response.msg +'. You might want to ask someone to look in the web logs for the details of this error. ' +
			'Please give the admin the time of this error so they can find the matching info in the logs.'

			console.log('Unknow error: ('+ xhr.status +')  '+ xhr.statusText +'  '+ response.msg);
			configInt.cache.modifyMessage.html(response.msg);
			alert(msg);
		}

		modifySelectRoles();
		configInt.cache.modifyRoleSubmit.prop("disabled", false);
		// configInt.cache.metarData.prop( "checked", false );
		// configInt.cache.ltgData.prop( "checked", false );
		// configInt.cache.graphData.prop( "checked", false );
		// configInt.cache.tickerData.prop( "checked", false );
		// configInt.cache.modifyCountryCode.combobox('value','')
		// configInt.cache.modifyRoleName.val('');
		// configInt.cache.modifyDescription.val('');

		
		$("table").trigger("update");
		drawPage();

		return response.msg;
	}
	
	var data = {};
	data['roleID'] = configInt.cache.modifyRole.val();
	data['metarData'] = configInt.cache.metarData.is(':checked') ? 1 : 0;
	data['ltgData'] = configInt.cache.ltgData.is(':checked') ? 1 : 0;
	data['graphData'] = configInt.cache.graphData.is(':checked') ? 1 : 0;
	data['tickerData'] = configInt.cache.tickerData.is(':checked') ? 1 : 0;

	data['regionID'] = configInt.cache.modifyCountryCode.val();
	data['roleName'] = configInt.cache.modifyRoleName.val();
	data['roleDescription'] = configInt.cache.modifyDescription.val();
	
	for (var variable in data) {
		console.log(variable);
		if(isUndefined(data[variable])) {
			var msg = "setRole: Missing needed data";
			console.log(msg);
			return 'Error: '+msg;
		}
	}
	
	var options = {};
	options['url'] = configInt.settings.baseURL + '/role/setProperties';
	options['data'] = data;
	options['success'] = callback;
	options['error'] = callback;

	restCall(options);
	
	return;
}

function modifySelectRoles() {	
	var callback = function(response, textStatus, xhr) { // Default call back func to set the input
		configInt.cache.modifyRole.empty();
		var options = '<option>Choose one</option>';
		var selectData = '';
		
		var spacing = '&nbsp;&nbsp;&nbsp;&nbsp;';
		for (var i = 0; i < response.length; i++) {
				options += '<option value="'+ response[i].id +'">'+ response[i].role +' ('+response[i].role_description+')' +spacing+'</option>';
				selectData += '<ul id="'+ response[i].id +'"><li>'+ response[i].metar +'</li><li>'+ response[i].ltg +'</li><li>'+ response[i].graph +'</li><li>'+ response[i].ticker +'</li>';
				selectData += '<li>'+ response[i].country_code +'</li><li>'+ response[i].role +'</li><li>'+ response[i].role_description +'</li></ul>';
		}

		configInt.cache.roles.html(options);
		configInt.cache.modifyRoleData.html(selectData);

		configInt.cache.modifyRole.change(function() {
			var data = $('#'+ configInt.cache.modifyRole.val() +' li').map(function () {
				return $(this).text();
			}).get();
			console.log("Handler for .change() called.");
			
			if(data[0] == 1) {
				configInt.cache.metarData.prop( "checked", true );
			} else {
				configInt.cache.metarData.prop( "checked", false );
			}
			if(data[1] == 1) {
				configInt.cache.ltgData.prop( "checked", true );
			} else {
				configInt.cache.ltgData.prop( "checked", false );
			}
			if(data[2] == 1) {
				configInt.cache.graphData.prop( "checked", true );
			} else {
				configInt.cache.graphData.prop( "checked", false );
			}
			if(data[3] == 1) {
				configInt.cache.tickerData.prop( "checked", true );
			} else {
				configInt.cache.tickerData.prop( "checked", false );
			}

			configInt.cache.modifyCountryCode.combobox('value', data[4]);
			configInt.cache.modifyRoleName.val(data[5]);
			configInt.cache.modifyDescription.val(data[6]);
		});
	}

	var options = {};
	options['url'] = configInt.settings.baseURL+'/user/listRoles/';
	options['success'] = callback;

	return restCall(options);
}


function createRegionRenameMap() {	
	var callback = function(response, textStatus, xhr) { // Default call back func to set the input

		var selectData = '';
		for (var i = 0; i < response.length; i++) {
				selectData += '<ul id="r'+ response[i].id +'"><li>'+ response[i].name +'</li><li>'+ response[i].description +'</li></ul>'
		}
		configInt.cache.renameData.html(selectData);

		console.log('createRenameDataMap');
	}

	var options = {};
	options['url'] = configInt.settings.baseURL+'/user/listRoles2/';
	options['success'] = callback;

	return restCall(options);
}

function regionRenameFullNames() {

	var data = $('#r'+ configInt.cache.regionID.val() +' li').map(function () {
		return $(this).text();
	}).get();
	
	// console.log(configInt.cache.regionID.val());
	if(!isUndefined(data)) {
		configInt.cache.newName.val(data[0]);
		configInt.cache.newDescription.val(data[1]);
	}

	return;
}
//###############################################################################################
//###############################################################################################
function fillSelectRoles(div,selectInputID,userID) {
	console.info('sgiven (div,selectInputID,userID): ('+ div +', '+ selectInputID +', '+ userID +')');
	var callback = function(response, textStatus, xhr) { // Default call back func to set the input
		div.children().remove();
		var selectData = '<table><tr valign="top"><td>Virtual Regions:</td><td><select id="'+ selectInputID +'" multiple="multiple" title="Please Select" size="1">';
		
		var spacing = '&nbsp;&nbsp;&nbsp;&nbsp;';
		for (var i = 0; i < response.length; i++) {
			if("used" in response[i] == true) {
				if(response[i].used == 1) {
					
					selectData += '<option disabled="disabled" value="'+ response[i].id +'" selected="selected">'+ response[i].role +spacing+'</option>';
				} else {
					selectData += '<option value="'+ response[i].id +'">'+ response[i].role +spacing+'</option>';
				}
			} else {
				selectData += '<option value="'+ response[i].id +'">'+ response[i].role +' ('+response[i].role_description+')' +spacing+'</option>';
			}
		}

		div.html(selectData+'</select></td></tr></table>');
		$('#'+selectInputID).selectList();
	}

	var options = {};
	if(isUndefined(userID)) {
		userID = '';
	}
	options['url'] = configInt.settings.baseURL+'/user/listRoles/'+userID;
	options['success'] = callback;

	return restCall(options);
}

function makeEditable(database) { // Enable the user to change the data in the DB they are looking at in the table
	$(".dblclick").editable(configInt.settings.baseURL +'/edit/' , {
		select    : true,
		event     : "dblclick",
		indicator : "<img src='/images/indicator.gif'>",
		tooltip   : "Doubleclick to edit...",		
		placeholder: '',
		style     : "inherit",
		submit    : 'OK',
		submitdata : {database : database},
		callback : function(value, settings) {
				 $(this).text($.parseJSON(value).value);
			 }
	});
	$(".editable_select").editable(configInt.settings.baseURL +'/edit/', { 
		type   : "select",
		event     : "dblclick",
		indicator : '<img src="/images/indicator.gif">',
		loadurl : '/data/country_codes_small.json',
		placeholder: '',
		style  : "inherit",
		submit : "OK",
		submitdata : {database : database},
		callback : function(value, settings) {
				 $(this).text($.parseJSON(value).value);
			 }
	});

	return;
}

function pagerMakeEditable(database,columnIDs,columnNames,column,selectColumn) { // Enable the user to change the data in the DB they are looking at in the table
	
	// Add the needed info to make the table editable
	for (key in column) {
	  // console.log("--> "+ column[key]);
	  var i = 0;
	  $('.tablesorter tbody tr td:nth-child(' + column[key] + ')').each(function () {
		$(this).addClass('dblclick');
		$(this).attr('id', columnIDs[i] +'-'+ columnNames[column[key]-1]); // This enables (y,x) table editing
		i++;
	  });
	};
	for (key in selectColumn) {
	  // console.log("--|> "+ selectColumn[key]);
	  i = 0;
	  $('.tablesorter tbody tr td:nth-child(' + selectColumn[key] + ')').each(function () {
		$(this).addClass('editable_select');
		$(this).attr('id', columnIDs[i] +'-'+ columnNames[selectColumn[key]-1]); // This enables (y,x) table editing
		i++;
	  });
	};


	$(".dblclick").editable(configInt.settings.baseURL +'/edit/' , {
		select    : true,
		event     : "dblclick",
		indicator : "<img src='/images/indicator.gif'>",
		tooltip   : "Doubleclick to edit...",		
		placeholder: '',
		style     : "inherit",
		submit    : 'OK',
		submitdata : {database : database},
		callback : function(value, settings) {
				 $(this).text($.parseJSON(value).value);
		},
		onsubmit: function(settings, td) {
			var input = $(td).find('input');
			var original = input.val();
			var type = $(td).attr('id').toString().match(/\-(.*)$/)[1];
			return editValidation(input,original,type);
		}
	});
	$(".editable_select").editable(configInt.settings.baseURL +'/edit/', { 
		type   : "select",
		event     : "dblclick",
		indicator : '<img src="/images/indicator.gif">',
		loadurl : '/data/country_codes_small.json',
		placeholder: '',
		style  : "inherit",
		submit : "OK",
		submitdata : {database : database},
		callback : function(value, settings) {
				 $(this).text($.parseJSON(value).value);
		}
	});

	// Lets only allow numbers in Last Updated so we don't see a 500 server error with bad data
	if($('.tablesorter thead tr th:nth-child(4) div').html().toString().match(/Latitude/)) { // RWIS -AN-D METAR Station Metadata tab
		console.log("Adding Station Metadata filters");
		$('.tablesorter thead tr td:nth-child(3)').find('input').alphanum({disallow: 'abcdefghijklmnopqrstuvwxyz', allow: '- :'});
		$('.tablesorter thead tr td:nth-child(4)').find('input').numeric({allowMinus: true, allowDecSep: true});
		$('.tablesorter thead tr td:nth-child(5)').find('input').numeric({allowMinus: true, allowDecSep: true});
		$('.tablesorter thead tr td:nth-child(6)').find('input').numeric({allowMinus: true, allowDecSep: true});
	} else if($('.tablesorter thead tr th:nth-child(3) div').html().toString().match(/Last Received Data/)) { // RWIS -AN-D METAR Station Association tab
		console.log("Adding Station Association filters");
		$('.tablesorter thead tr td:nth-child(3)').find('input').alphanum({disallow: 'abcdefghijklmnopqrstuvwxyz', allow: '-'});
	} else if($('.tablesorter thead tr th:nth-child(5) div').html().toString().match(/Date Added/)) { // User Management tab
		console.log("Adding User Management filters");
		$('.tablesorter thead tr td:nth-child(5)').find('input').alphanum({disallow: 'abcdefghijklmnopqrstuvwxyz', allow: '-'});
	} else if($('.tablesorter thead tr th:nth-child(2) div').html().toString().match(/User Count/)) { // Region Setup
		console.log("Adding Region filters");
		$('.tablesorter thead tr td:nth-child(2)').find('input').numeric();
		$('.tablesorter thead tr td:nth-child(5)').find('input').alphanum({disallow: '0123456789bcdghijkmnopqvwxyz'});
		$('.tablesorter thead tr td:nth-child(6)').find('input').alphanum({disallow: '0123456789bcdghijkmnopqvwxyz'});
		$('.tablesorter thead tr td:nth-child(7)').find('input').alphanum({disallow: '0123456789bcdghijkmnopqvwxyz'});
		$('.tablesorter thead tr td:nth-child(8)').find('input').alphanum({disallow: '0123456789bcdghijkmnopqvwxyz'});
	}

	return;
}

function editValidation(input,original,type) { // Lets do some basic checking to make sure the user is giving a good value
	var errorThrown = 0;
	if(type == 'lat') {
		if(isLatitude(original)) {
			console.log("Validation correct: is Latitude");
			return true;
		} else {
			errorThrown = 'Error: validation failed for the given Latitude value. Need a value between -90 and 90.';
		}
	} else if(type == 'lon') {
		if(isLongitude(original)) {
			console.log("Validation correct: is Longitude");
			return true;
		} else {
			errorThrown = 'Error: validation failed for the given Longitude value. Need a value between -180 and 180.';
		}
	} else if(type == 'alt') {
		if (isNumeric(original)) {
			console.log("Validation correct: is Numeric value for Altitude");
			return true;
		} else {
			errorThrown = 'Validation failed. not a Numeric value for Altitude';
		}
	} else if(type == 'station_name') {
		if(!isUndefined(original) && original != ''){
			console.log("Validation correct: is Numeric value for Altitude");
			return true;
		} else {
			errorThrown = 'Validation failed. Input must not be blank!';
		}
	}

	if(!errorThrown == 0) {
		console.log(errorThrown);
		alert(errorThrown);
		input.css('background-color','#c00').css('color','#fff');
		return false;
	}
	return true;
}

function isLatitude(value) {
  if (value == null || !value.toString().match(/^(-?[1-8]?\d(?:\.\d{1,18})?|90(?:\.0{1,18})?)$/)) return false;
  return true;
}
function isLongitude(value) {
  if (value == null || !value.toString().match(/^(-?(?:1[0-7]|[1-9])?\d(?:\.\d{1,18})?|180(?:\.0{1,18})?)$/)) return false;
  return true;
}
function isNumeric(value) {
  if (value == null || !value.toString().match(/^[-]?\d*\.?\d*$/)) return false;
  return true;
}
function isFloat(value) {
  if (value == null || !value.toString().match(/^\d{0,2}(?:\.\d{0,2}){0,1}$/)) return false;
  return true;
}

function setCombobox(div,getDataType,boxOptions) { // setup a jquery combobox on a select box
	// This is slower then autocomplete, but this does have more features
	// http://jonathan.tang.name/code/jquery_combobox
	var callback = function(response, textStatus, xhr) {
		div.html('<option value="" disabled="disabled" selected="selected"></option>');
		for(var item in response) {
			div.append('<option value="'+response[item]['id']+'">'+response[item]['name']+'</option>');
		};
		div.combobox(boxOptions);
		$('.ui-autocomplete-input').css('width','350px');
	}

	var options = {};
	if(getDataType.match(/^http/) || getDataType.match(/^\//)) {
		options['url'] = getDataType;
	} else {
		options['url'] = configInt.settings.baseURL +"/getSimple/"+ getDataType;
	}
	options['success'] = callback;

	return restCall(options);
}
function setAutocomplete(div,getDataType,boxOptions) { // setup a jquery autocomplete on a input field
	// http://jqueryui.com/autocomplete/

	div.autocomplete({
		source: function( request, response ) {
			var request = $.ajax({
				url: configInt.settings.baseURL +'/get/'+ getDataType +'/'+ request.term,
				method: 'GET',
				dataType: 'json',
				cache: false,
				timeout: 30000,
			});
			request.done(function (data, textStatus, jqXHR){
				response($.map(data, function(item) {
					return {
						label: item.name,
						id: item.id,
					};
				}));
			});
			request.fail(function (jqXHR, textStatus, errorThrown){
				console.error("The following error occured: "+ textStatus +'  '+ errorThrown ); // log the error to the console
				status = 'Error: '+ errorThrown;
			});
		},
		minLength: 1,
		open: function() {
			$( this ).removeClass( "ui-corner-all" ).addClass( "ui-corner-top" );
		},
		close: function() {
			$( this ).removeClass( "ui-corner-top" ).addClass( "ui-corner-all" );
		}
	});
}
function setSelectBox(div,getDataType) { // setup a jquery autocomplete on a input field
	var callback = function(response, textStatus, xhr) {
		div.html('<option value="" disabled="disabled" selected="selected">Please select</option>');
		for(var item in response) {	
			// console.log(response[item]['id'] +'|'+ response[item]['var']);
			div.append('<option value="'+response[item]['id']+'">'+response[item]['name']+'</option>');
		};
	}

	var options = {};
	options['url'] = configInt.settings.baseURL +"/getSimple/"+ getDataType;
	options['success'] = callback;

	return restCall(options);
}

function setOrganizationSelect() {
	var callback = function(response, textStatus, xhr) {
		configInt.cache.orgID.html('<option value="">Choose one</option>');
		for(var item in response) {	
			configInt.cache.orgID.append('<option value='+response[item]+'>'+response[item]+'</option>');
		};
		configInt.cache.orgID.combobox();
	}

	var options = {};
	options['url'] = configInt.settings.baseURL + "/get/organizationID";
	options['success'] = callback;

	return restCall(options);
}

function updateClock() {
	var currentTime = new Date();
	var year = currentTime.getUTCFullYear();
	var month = currentTime.getUTCMonth()+1;
	var day = currentTime.getUTCDate();
	var hours = currentTime.getUTCHours();
	var minutes = currentTime.getUTCMinutes();
	var seconds = currentTime.getUTCSeconds();

	hours = ( hours < 10 ? "0" : "" ) + hours;
	minutes = ( minutes < 10 ? "0" : "" ) + minutes;
	seconds = ( seconds < 10 ? "0" : "" ) + seconds;
	month = ( month < 10 ? "0" : "" ) + month;
	day = ( day < 10 ? "0" : "" ) + day;

	var currentTimeString =  year +"-"+ month +"-"+ day +"  "+ hours +":"+ minutes +":"+ seconds +" UTC";
   

	$("#clock").html(currentTimeString); 
}

function inputValidation(givenDiv,checkType,checkPrams) { // Used to check the form field for valid user input
	// NOTE: This does not protect the API and checking still needs to happen on the backend
	// Example: if(inputValidation('addRole','length',[3,20])) { run() }
	// Assumption: if the given div is devTest, this code will output the message to devTestInfo

	div = window.configInt.cache[givenDiv];
	divInfo = window.configInt.cache[givenDiv+'Info'];

	var msg;
	if(checkType == 'notBlank') {
		if(isUndefined(div.val()) || div.val() == null || div.val() == 'Choose one' || div.val() == 'blank'){
			msg = "Input must not be blank!";
		}
	} else if(checkType == 'typeLength') {
		characterType = checkPrams[0];
		min = checkPrams[1];
		max = checkPrams[2];
		if(isUndefined(characterType)) {
			console.log("Error: Missing needed character type variable");
		}
		if(isUndefined(min) || !isUndefined(max)) {
			console.log("Error: Missing needed length variables");
		}


		if(characterType == 'lower') {
			regex = '^[a-z0-9\-\_\.]{'+min+','+max+'}$';
			if(!div.val().match(regex)){
				msg = "Input must be lower case alphanumeric with '_' or '-' or ',' <br /> Also input must be at least "+min+" letters and less than "+max+"!";
			}
		} else if(characterType == 'password') {
			regex = '^[a-z0-9\~\@\#\%\^\&\(\)\-\_\{\}\.]{'+min+','+max+'}$';
			if(!div.val().match(regex)){
				msg = "Input can be mixed case alphanumeric or the following: ~ @ # % ^ & ( ) - _ { } . <br /> Also input must be at least "+min+" letters and less than "+max+"!";
			}
		} else if(characterType == 'mixed') {
			regex = '^[a-zA-Z0-9\-\_\.]{'+min+','+max+'}$';
			if(!div.val().match(regex)){
				msg = "Input can be mixed case alphanumeric or the following: _ . - <br /> Also input must be at least "+min+" letters and less than "+max+"!";
			}
		} else if(characterType == 'username') {
			regex = '^[a-zA-Z0-9\-\_\.\@]{'+min+','+max+'}$';
			if(!div.val().match(regex)){
				msg = "Input can be mixed case alphanumeric or the following: _ . - @ <br /> Also input must be at least "+min+" letters and less than "+max+"!";
			}
		} else if(characterType == 'number') {
			regex = '^[0-9]{'+min+','+max+'}$';
			if(!div.val().match(regex)){
				msg = "Input must be a number. Also input must be at least "+min+" letters and less than "+max+"!";
			}
		} else {
			console.log('Error: given characterType is not one that can be useded: ('+characterType+')');
			return false;
		}
	} else if(checkType == 'length') {
		min = checkPrams[0];
		max = checkPrams[1];
		if(!isUndefined(min) || !isUndefined(max)) {
			console.log("Error: Missing needed length variables");
		}

		if(div.val() == null || div.val() == 'Choose one' || div.val() == 'blank'){
			msg = "Input must not be blank!";
		} else if(div.val().length < min || div.val().length > max){
			msg = "Input must be at least "+min+" letters and less than "+max+"!";
		}
	} else {
		console.log("Error: Bad checkType given: ("+checkType+")");
		return false;
	}

	if(!isUndefined(msg)) {
		div.addClass("ui-state-highlight");
		console.log(msg);
		// divInfo.text(msg);
		alertIcon = '<span style="float: left; margin-right: .3em;" class="ui-icon ui-icon-info"></span>';
		divInfo.html(alertIcon+msg);
		divInfo.addClass("ui-state-highlight");
		return false;
	}

	//if it's valid
	div.removeClass("ui-state-highlight");
	divInfo.text("");
	divInfo.removeClass("ui-state-highlight");
	return true;
}

function restCall(options) { // general ajax call to the rest interface, given a callback and a url to use
	var status;
	if(isUndefined(options.url)) {
		status = "Error: restCall: Given options' URL not defined"
		console.error(status);
		return(status);
	}
	if(isUndefined(options.success)) {
		status = "Error: restCall: Given options' success not defined"
		console.error(status);
		return(status);
	}

	var request,
		ajaxOptions,
		ajaxDefaults = {
			// url:
			// success: , // This will be a passed in option for a callback to deal with the requested data
			// error: , // Here is another one you might want to create a callback for
			type: 'POST',
			dataType: 'json',
			//cache: false,
			timeout: 30000,
			fail: function (jqXHR, textStatus, errorThrown){
					console.log("The following error occured: "+ textStatus +'  '+ errorThrown +'. You might want to ask someone to look in the web logs for the details of this error. ' +
					'Please give the admin the time of this error so they can find the matching info in the logs.'); // log the error to the console
				}
		};

	ajaxOptions = _.defaults(options, ajaxDefaults); 
	request = $.ajax(ajaxOptions);

	return(request);
}
//###############################################################################################################################################################

function pagerTable(type,startSize,column,selectColumn){
	if(isUndefined(type)) {
		type = '';
	}
	if(isUndefined(startSize)) {
		startSize = 15;
	}

	var columnIDs = new Array();
	var columnNames = new Array();

	// Initialize tablesorter
	// ***********************
	$("table")
		.tablesorter({
			theme: 'blue',
			widthFixed: true,
			sortLocaleCompare: true, // needed for accented characters in the data
			sortList: [ [0,1] ],
			widgets: ['zebra', 'filter']
		})

		// initialize the pager plugin
		// ****************************
		.tablesorterPager({

			// **********************************
			//  Description of ALL pager options
			// **********************************

			// target the pager markup - see the HTML block below
			container: $(".pager"),

			// use this format: "http:/mydatabase.com?page={page}&size={size}&{sortList:col}"
			// where {page} is replaced by the page number (or use {page+1} to get a one-based index),
			// {size} is replaced by the number of records to show,
			// {sortList:col} adds the sortList to the url into a "col" array, and {filterList:fcol} adds
			// the filterList to the url into an "fcol" array.
			// So a sortList = [[2,0],[3,0]] becomes "&col[2]=0&col[3]=0" in the url
			// and a filterList = [[2,Blue],[3,13]] becomes "&fcol[2]=Blue&fcol[3]=13" in the url
			ajaxUrl : '/rest/v1.0/get'+ type +'/pagerTable?size={size}&page={page}&{filterList:filter}&{sortList:column}',
			//ajaxUrl : '/data/test.json?size={size}&page={page}&{filterList:filter}&{sortList:column}',

			// modify the url after all processing has been applied
			// customAjaxUrl: function(table, url) {
			// 		// manipulate the url string as you desire
			// 		// url += '&cPage=' + window.location.pathname;
			// 		// trigger my custom event
			// 		$(table).trigger('changingUrl', url);
			// 		// send the server the current page
			// 		return url;
			// },

			// add more ajax settings here
			// see http://api.jquery.com/jQuery.ajax/#jQuery-ajax-settings
			ajaxObject: {
				dataType: 'json',
				cache: false
			},

			// process ajax so that the following information is returned:
			// [ total_rows (number), rows (array of arrays), headers (array; optional) ]
			// example:
			// [
			//   100,  // total rows
			//   [
			//     [ "row1cell1", "row1cell2", ... "row1cellN" ],
			//     [ "row2cell1", "row2cell2", ... "row2cellN" ],
			//     ...
			//     [ "rowNcell1", "rowNcell2", ... "rowNcellN" ]
			//   ],
			//   [ "header1", "header2", ... "headerN" ] // optional
			// ]
			// OR
			// return [ total_rows, $rows (jQuery object; optional), headers (array; optional) ]
			ajaxProcessing: function(data){
				// console.log("Doing: ajaxProcessing");
				if (data && data.hasOwnProperty('rows')) {
					if(data.hasOwnProperty('ids')) {
						columnIDs = data.ids;
						columnNames = data.names;
					}

					var r, row, c, d = data.rows,
					// total number of rows (required)
					total = data.total_rows,
					// array of header names (optional)
					headers = data.headers,
					// all rows: array of arrays; each internal array has the table cell data for that row
					rows = [],
					// len should match pager set size (c.size)
					len = d.length;
					// this will depend on how the json is set up - see City0.json
					// rows
					for ( r=0; r < len; r++ ) {
						row = []; // new row array
						// cells
						for ( c in d[r] ) {
							if (typeof(c) === "string") {
								row.push(d[r][c]); // add each table cell data to row array
							}
						}
						rows.push(row); // add new row array to rows array
					}

					// in version 2.10, you can optionally return $(rows) a set of table rows within a jQuery object
					return [ total, rows, headers ];
				}
			},

			// output string - default is '{page}/{totalPages}'; possible variables: {page}, {totalPages}, {startRow}, {endRow} and {totalRows}
			output: '{startRow} to {endRow} ({totalRows})',

			// apply disabled classname to the pager arrows when the rows at either extreme is visible - default is true
			updateArrows: true,

			// starting page of the pager (zero based index)
			page: 0,

			// Number of visible rows - default is 10
			size: startSize,

			// if true, the table will remain the same height no matter how many records are displayed. The space is made up by an empty
			// table row set to a height to compensate; default is false
			fixedHeight: false,

			// remove rows from the table to speed up the sort of large tables.
			// setting this to false, only hides the non-visible rows; needed if you plan to add/remove rows with the pager enabled.
			removeRows: false,

			// css class names of pager arrows
			cssNext        : '.next',  // next page arrow
			cssPrev        : '.prev',  // previous page arrow
			cssFirst       : '.first', // go to first page arrow
			cssLast        : '.last',  // go to last page arrow
			cssPageDisplay : '.pagedisplay', // location of where the "output" is displayed
			cssPageSize    : '.pagesize', // page size selector - select dropdown that sets the "size" option
			cssErrorRow    : 'tablesorter-errorRow', // error information row

			// class added to arrows when at the extremes (i.e. prev/first arrows are "disabled" when on the first page)
			cssDisabled    : 'disabled' // Note there is no period "." in front of this class name

		});


	jQuery.fn.contentChange = function(callback){
	var elms = jQuery(this);
	elms.each(
	  function(i){
		var elm = jQuery(this);
		elm.data("lastContents", elm.html());
		window.watchContentChange = window.watchContentChange ? window.watchContentChange : [];
		window.watchContentChange.push({"element": elm, "callback": callback});
	  }
	)
	return elms;
	}
	setInterval(function(){
	if(window.watchContentChange){
	  for( i in window.watchContentChange){
		if(window.watchContentChange[i].element.data("lastContents") != window.watchContentChange[i].element.html()){
		  window.watchContentChange[i].callback.apply(window.watchContentChange[i].element);
		  window.watchContentChange[i].element.data("lastContents", window.watchContentChange[i].element.html())
		};
	  }
	}
	},500);


	function tableSorterChange(){
		// var element = $(this);
		// alert("it was '"+element.data("lastContents")+"' and now its '"+element.html()+"'");
		var db = 'cloud';
		if(type.match(/^metar/)) {
			db = 'metar';
		}
		console.log('calling: pagerMakeEditable  Using database: '+db);
		pagerMakeEditable(db,columnIDs,columnNames,column,selectColumn);
	}

	$('div#resultsTable').contentChange( tableSorterChange );

	// $("table").on("filterEnd",function(e, table) {
	// 	console.log("Got filterEnd");
	// 	pagerMakeEditable('cloud',columnIDs,columnNames,column,selectColumn);
	// });
	// $("resultsTable").load(function(e, table) {
	// 	console.log("Got loaded");
	// 	pagerMakeEditable('cloud',columnIDs,columnNames,column,selectColumn);
	// });	

	return;
};
//###############################################################################################################################################################
//###############################################################################################################################################################
function isUndefined(object) {
	return typeof object === "undefined";
}

function tableDateString(d){
  function pad(n){return n<10 ? '0'+n : n}
  return d.getUTCFullYear()+'-'
	  + pad(d.getUTCMonth()+1)+'-'
	  + pad(d.getUTCDate())+' '
	  + pad(d.getUTCHours())+':'
	  + pad(d.getUTCMinutes())+':'
	  + pad(d.getUTCSeconds())
}

function print_r(arr,level) { // data dump
	// Example: alert(print_r(status));
	var dumped_text = "";
	if(!level) level = 0;

	//The padding given at the beginning of the line.
	var level_padding = "";
	for(var j=0;j<level+1;j++) level_padding += "    ";

	if(typeof(arr) == 'object') { //Array/Hashes/Objects 
		for(var item in arr) {
			var value = arr[item];

			if(typeof(value) == 'object') { //If it is an array,
				dumped_text += level_padding + "'" + item + "' ...\n";
				dumped_text += print_r(value,level+1);
			} else {
				dumped_text += level_padding + "'" + item + "' => \"" + value + "\"\n";
			}
		}
	} else { //Stings/Chars/Numbers etc.
		dumped_text = "===>"+arr+"<===("+typeof(arr)+")";
	}
	return dumped_text;
}
//###############################################################################################################################################################