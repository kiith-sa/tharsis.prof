"use strict";
var items = [
{"tharsis.prof.chunkyeventlist" : "tharsis/prof/chunkyeventlist.html"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList" : "tharsis/prof/chunkyeventlist/ChunkyEventList.html"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.Chunk" : "tharsis/prof/chunkyeventlist/ChunkyEventList.Chunk.html"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.Chunk.lastStartTime" : "tharsis/prof/chunkyeventlist/ChunkyEventList.Chunk.html#lastStartTime"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.Chunk.data" : "tharsis/prof/chunkyeventlist/ChunkyEventList.Chunk.html#data"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.Chunk.startTime" : "tharsis/prof/chunkyeventlist/ChunkyEventList.Chunk.html#startTime"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.Generator" : "tharsis/prof/chunkyeventlist/ChunkyEventList.Generator.html"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.Generator.GeneratedEvent" : "tharsis/prof/chunkyeventlist/ChunkyEventList.Generator.GeneratedEvent.html"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.Generator.GeneratedEvent.chunk" : "tharsis/prof/chunkyeventlist/ChunkyEventList.Generator.GeneratedEvent.html#chunk"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.Generator.GeneratedEvent.startByte" : "tharsis/prof/chunkyeventlist/ChunkyEventList.Generator.GeneratedEvent.html#startByte"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.Generator.GeneratedEvent.endByte" : "tharsis/prof/chunkyeventlist/ChunkyEventList.Generator.GeneratedEvent.html#endByte"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.Generator.GeneratedEvent.event" : "tharsis/prof/chunkyeventlist/ChunkyEventList.Generator.GeneratedEvent.html#event"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.Generator.events_" : "tharsis/prof/chunkyeventlist/ChunkyEventList.Generator.html#events_"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.Generator.chunkIndex_" : "tharsis/prof/chunkyeventlist/ChunkyEventList.Generator.html#chunkIndex_"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.Generator.eventPos_" : "tharsis/prof/chunkyeventlist/ChunkyEventList.Generator.html#eventPos_"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.Generator.currentChunkEvents_" : "tharsis/prof/chunkyeventlist/ChunkyEventList.Generator.html#currentChunkEvents_"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.Generator.this" : "tharsis/prof/chunkyeventlist/ChunkyEventList.Generator.html#this"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.Generator.generate" : "tharsis/prof/chunkyeventlist/ChunkyEventList.Generator.html#generate"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.Slice" : "tharsis/prof/chunkyeventlist/ChunkyEventList.Slice.html"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.Slice.front" : "tharsis/prof/chunkyeventlist/ChunkyEventList.Slice.html#front"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.Slice.popFront" : "tharsis/prof/chunkyeventlist/ChunkyEventList.Slice.html#popFront"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.Slice.empty" : "tharsis/prof/chunkyeventlist/ChunkyEventList.Slice.html#empty"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.Slice.save" : "tharsis/prof/chunkyeventlist/ChunkyEventList.Slice.html#save"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.TimeSlice" : "tharsis/prof/chunkyeventlist/ChunkyEventList.TimeSlice.html"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.TimeSlice.this" : "tharsis/prof/chunkyeventlist/ChunkyEventList.TimeSlice.html#this"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.TimeSlice.front" : "tharsis/prof/chunkyeventlist/ChunkyEventList.TimeSlice.html#front"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.TimeSlice.popFront" : "tharsis/prof/chunkyeventlist/ChunkyEventList.TimeSlice.html#popFront"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.TimeSlice.empty" : "tharsis/prof/chunkyeventlist/ChunkyEventList.TimeSlice.html#empty"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.TimeSlice.save" : "tharsis/prof/chunkyeventlist/ChunkyEventList.TimeSlice.html#save"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.SliceExtents" : "tharsis/prof/chunkyeventlist/ChunkyEventList.SliceExtents.html"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.SliceExtents.firstChunk" : "tharsis/prof/chunkyeventlist/ChunkyEventList.SliceExtents.html#firstChunk"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.SliceExtents.firstEventStart" : "tharsis/prof/chunkyeventlist/ChunkyEventList.SliceExtents.html#firstEventStart"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.SliceExtents.lastChunk" : "tharsis/prof/chunkyeventlist/ChunkyEventList.SliceExtents.html#lastChunk"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.SliceExtents.lastEventEnd" : "tharsis/prof/chunkyeventlist/ChunkyEventList.SliceExtents.html#lastEventEnd"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.SliceExtents.isValid" : "tharsis/prof/chunkyeventlist/ChunkyEventList.SliceExtents.html#isValid"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.chunkStorage_" : "tharsis/prof/chunkyeventlist/ChunkyEventList.html#chunkStorage_"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.chunks_" : "tharsis/prof/chunkyeventlist/ChunkyEventList.html#chunks_"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.this" : "tharsis/prof/chunkyeventlist/ChunkyEventList.html#this"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.outOfSpace" : "tharsis/prof/chunkyeventlist/ChunkyEventList.html#outOfSpace"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.provideStorage" : "tharsis/prof/chunkyeventlist/ChunkyEventList.html#provideStorage"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.generator" : "tharsis/prof/chunkyeventlist/ChunkyEventList.html#generator"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.addChunk" : "tharsis/prof/chunkyeventlist/ChunkyEventList.html#addChunk"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.slice" : "tharsis/prof/chunkyeventlist/ChunkyEventList.html#slice"},
{"tharsis.prof.chunkyeventlist.ChunkyEventList.timeSlice" : "tharsis/prof/chunkyeventlist/ChunkyEventList.html#timeSlice"},
{"tharsis.prof.chunkyeventlist.ChunkyEventGenerator" : "tharsis/prof/chunkyeventlist.html#ChunkyEventGenerator"},
{"tharsis.prof.chunkyeventlist.ChunkyEventSlice" : "tharsis/prof/chunkyeventlist.html#ChunkyEventSlice"},
{"tharsis.prof.chunkyeventlist.ChunkyZoneGenerator" : "tharsis/prof/chunkyeventlist/ChunkyZoneGenerator.html"},
{"tharsis.prof.chunkyeventlist.ChunkyZoneGenerator.GeneratedZoneData" : "tharsis/prof/chunkyeventlist/ChunkyZoneGenerator.GeneratedZoneData.html"},
{"tharsis.prof.chunkyeventlist.ChunkyZoneGenerator.GeneratedZoneData.extents" : "tharsis/prof/chunkyeventlist/ChunkyZoneGenerator.GeneratedZoneData.html#extents"},
{"tharsis.prof.chunkyeventlist.ChunkyZoneGenerator.GeneratedZoneData.zoneData" : "tharsis/prof/chunkyeventlist/ChunkyZoneGenerator.GeneratedZoneData.html#zoneData"},
{"tharsis.prof.chunkyeventlist.ChunkyZoneGenerator.ExtendedZoneInfo" : "tharsis/prof/chunkyeventlist/ChunkyZoneGenerator.ExtendedZoneInfo.html"},
{"tharsis.prof.chunkyeventlist.ChunkyZoneGenerator.this" : "tharsis/prof/chunkyeventlist/ChunkyZoneGenerator.html#this"},
{"tharsis.prof.chunkyeventlist.ChunkyZoneGenerator.generate" : "tharsis/prof/chunkyeventlist/ChunkyZoneGenerator.html#generate"},
{"tharsis.prof.event" : "tharsis/prof/event.html"},
{"tharsis.prof.event.EventID" : "tharsis/prof/event/EventID.html"},
{"tharsis.prof.event.VariableType" : "tharsis/prof/event/VariableType.html"},
{"tharsis.prof.event.variableType" : "tharsis/prof/event.html#variableType"},
{"tharsis.prof.event.Variable" : "tharsis/prof/event/Variable.html"},
{"tharsis.prof.event.Variable.type" : "tharsis/prof/event/Variable.html#type"},
{"tharsis.prof.event.Variable.toString" : "tharsis/prof/event/Variable.html#toString"},
{"tharsis.prof.event.Variable.varInt" : "tharsis/prof/event/Variable.html#varInt"},
{"tharsis.prof.event.Variable.varUint" : "tharsis/prof/event/Variable.html#varUint"},
{"tharsis.prof.event.Variable.varFloat" : "tharsis/prof/event/Variable.html#varFloat"},
{"tharsis.prof.event.Event" : "tharsis/prof/event/Event.html"},
{"tharsis.prof.event.Event.id" : "tharsis/prof/event/Event.html#id"},
{"tharsis.prof.event.Event.time" : "tharsis/prof/event/Event.html#time"},
{"tharsis.prof.event.Event.info" : "tharsis/prof/event/Event.html#info"},
{"tharsis.prof.profiler" : "tharsis/prof/profiler.html"},
{"tharsis.prof.profiler.Zone" : "tharsis/prof/profiler/Zone.html"},
{"tharsis.prof.profiler.Zone.this" : "tharsis/prof/profiler/Zone.html#this"},
{"tharsis.prof.profiler.Zone.variableEvent" : "tharsis/prof/profiler/Zone.html#variableEvent"},
{"tharsis.prof.profiler.Profiler" : "tharsis/prof/profiler/Profiler.html"},
{"tharsis.prof.profiler.Profiler.Diagnostics" : "tharsis/prof/profiler/Profiler.Diagnostics.html"},
{"tharsis.prof.profiler.Profiler.maxEventBytes" : "tharsis/prof/profiler/Profiler.html#maxEventBytes"},
{"tharsis.prof.profiler.Profiler.this" : "tharsis/prof/profiler/Profiler.html#this"},
{"tharsis.prof.profiler.Profiler.outOfSpace" : "tharsis/prof/profiler/Profiler.html#outOfSpace"},
{"tharsis.prof.profiler.Profiler.diagnostics" : "tharsis/prof/profiler/Profiler.html#diagnostics"},
{"tharsis.prof.profiler.Profiler.checkpointEvent" : "tharsis/prof/profiler/Profiler.html#checkpointEvent"},
{"tharsis.prof.profiler.Profiler.variableEvent" : "tharsis/prof/profiler/Profiler.html#variableEvent"},
{"tharsis.prof.profiler.Profiler.zoneStartEvent" : "tharsis/prof/profiler/Profiler.html#zoneStartEvent"},
{"tharsis.prof.profiler.Profiler.zoneEndEvent" : "tharsis/prof/profiler/Profiler.html#zoneEndEvent"},
{"tharsis.prof.profiler.Profiler.reset" : "tharsis/prof/profiler/Profiler.html#reset"},
{"tharsis.prof.profiler.Profiler.profileData" : "tharsis/prof/profiler/Profiler.html#profileData"},
{"tharsis.prof.profiler.Profiler.zoneNestLevel" : "tharsis/prof/profiler/Profiler.html#zoneNestLevel"},
{"tharsis.prof.despikersender" : "tharsis/prof/despikersender.html"},
{"tharsis.prof.despikersender.DespikerSenderException" : "tharsis/prof/despikersender/DespikerSenderException.html"},
{"tharsis.prof.despikersender.DespikerSender" : "tharsis/prof/despikersender/DespikerSender.html"},
{"tharsis.prof.despikersender.DespikerSender.maxProfilers" : "tharsis/prof/despikersender/DespikerSender.html#maxProfilers"},
{"tharsis.prof.despikersender.DespikerSender.this" : "tharsis/prof/despikersender/DespikerSender.html#this"},
{"tharsis.prof.despikersender.DespikerSender.sending" : "tharsis/prof/despikersender/DespikerSender.html#sending"},
{"tharsis.prof.despikersender.DespikerSender.frameFilter" : "tharsis/prof/despikersender/DespikerSender.html#frameFilter"},
{"tharsis.prof.despikersender.DespikerSender.startDespiker" : "tharsis/prof/despikersender/DespikerSender.html#startDespiker"},
{"tharsis.prof.despikersender.DespikerSender.reset" : "tharsis/prof/despikersender/DespikerSender.html#reset"},
{"tharsis.prof.despikersender.DespikerSender.update" : "tharsis/prof/despikersender/DespikerSender.html#update"},
{"tharsis.prof.despikersender.DespikerSender.send" : "tharsis/prof/despikersender/DespikerSender.html#send"},
{"tharsis.prof.despikersender.DespikerFrameFilter" : "tharsis/prof/despikersender/DespikerFrameFilter.html"},
{"tharsis.prof.despikersender.DespikerFrameFilter.info" : "tharsis/prof/despikersender/DespikerFrameFilter.html#info"},
{"tharsis.prof.despikersender.DespikerFrameFilter.nestLevel" : "tharsis/prof/despikersender/DespikerFrameFilter.html#nestLevel"},
{"tharsis.prof.accumulatedzonerange" : "tharsis/prof/accumulatedzonerange.html"},
{"tharsis.prof.accumulatedzonerange.AccumulatedZoneData" : "tharsis/prof/accumulatedzonerange/AccumulatedZoneData.html"},
{"tharsis.prof.accumulatedzonerange.AccumulatedZoneData.zoneData" : "tharsis/prof/accumulatedzonerange/AccumulatedZoneData.html#zoneData"},
{"tharsis.prof.accumulatedzonerange.AccumulatedZoneData.accumulated" : "tharsis/prof/accumulatedzonerange/AccumulatedZoneData.html#accumulated"},
{"tharsis.prof.accumulatedzonerange.defaultMatch" : "tharsis/prof/accumulatedzonerange.html#defaultMatch"},
{"tharsis.prof.accumulatedzonerange.accumulatedZoneRange" : "tharsis/prof/accumulatedzonerange.html#accumulatedZoneRange"},
{"tharsis.prof.csv" : "tharsis/prof/csv.html"},
{"tharsis.prof.csv.writeCSVTo" : "tharsis/prof/csv.html#writeCSVTo"},
{"tharsis.prof.csv.csvEventRange" : "tharsis/prof/csv.html#csvEventRange"},
{"tharsis.prof.csv.CSVEventRange" : "tharsis/prof/csv/CSVEventRange.html"},
{"tharsis.prof.csv.CSVEventRange.front" : "tharsis/prof/csv/CSVEventRange.html#front"},
{"tharsis.prof.csv.CSVEventRange.popFront" : "tharsis/prof/csv/CSVEventRange.html#popFront"},
{"tharsis.prof.csv.CSVEventRange.empty" : "tharsis/prof/csv/CSVEventRange.html#empty"},
{"tharsis.prof.csv.isCharOutput" : "tharsis/prof/csv.html#isCharOutput"},
{"tharsis.prof.ranges" : "tharsis/prof/ranges.html"},
{"tharsis.prof.ranges.ZoneData" : "tharsis/prof/ranges/ZoneData.html"},
{"tharsis.prof.ranges.ZoneData.id" : "tharsis/prof/ranges/ZoneData.html#id"},
{"tharsis.prof.ranges.ZoneData.parentID" : "tharsis/prof/ranges/ZoneData.html#parentID"},
{"tharsis.prof.ranges.ZoneData.nestLevel" : "tharsis/prof/ranges/ZoneData.html#nestLevel"},
{"tharsis.prof.ranges.ZoneData.startTime" : "tharsis/prof/ranges/ZoneData.html#startTime"},
{"tharsis.prof.ranges.ZoneData.duration" : "tharsis/prof/ranges/ZoneData.html#duration"},
{"tharsis.prof.ranges.ZoneData.info" : "tharsis/prof/ranges/ZoneData.html#info"},
{"tharsis.prof.ranges.ZoneData.endTime" : "tharsis/prof/ranges/ZoneData.html#endTime"},
{"tharsis.prof.ranges.zoneRange" : "tharsis/prof/ranges.html#zoneRange"},
{"tharsis.prof.ranges.buildZoneData" : "tharsis/prof/ranges.html#buildZoneData"},
{"tharsis.prof.ranges.NamedVariable" : "tharsis/prof/ranges/NamedVariable.html"},
{"tharsis.prof.ranges.NamedVariable.name" : "tharsis/prof/ranges/NamedVariable.html#name"},
{"tharsis.prof.ranges.NamedVariable.time" : "tharsis/prof/ranges/NamedVariable.html#time"},
{"tharsis.prof.ranges.NamedVariable.variable" : "tharsis/prof/ranges/NamedVariable.html#variable"},
{"tharsis.prof.ranges.variableRange" : "tharsis/prof/ranges.html#variableRange"},
{"tharsis.prof.ranges.VariableRange" : "tharsis/prof/ranges/VariableRange.html"},
{"tharsis.prof.ranges.VariableRange.this" : "tharsis/prof/ranges/VariableRange.html#this"},
{"tharsis.prof.ranges.VariableRange.front" : "tharsis/prof/ranges/VariableRange.html#front"},
{"tharsis.prof.ranges.VariableRange.popFront" : "tharsis/prof/ranges/VariableRange.html#popFront"},
{"tharsis.prof.ranges.VariableRange.empty" : "tharsis/prof/ranges/VariableRange.html#empty"},
{"tharsis.prof.ranges.VariableRange.save" : "tharsis/prof/ranges/VariableRange.html#save"},
{"tharsis.prof.ranges.ZoneRange" : "tharsis/prof/ranges/ZoneRange.html"},
{"tharsis.prof.ranges.ZoneRange.this" : "tharsis/prof/ranges/ZoneRange.html#this"},
{"tharsis.prof.ranges.ZoneRange.front" : "tharsis/prof/ranges/ZoneRange.html#front"},
{"tharsis.prof.ranges.ZoneRange.popFront" : "tharsis/prof/ranges/ZoneRange.html#popFront"},
{"tharsis.prof.ranges.ZoneRange.empty" : "tharsis/prof/ranges/ZoneRange.html#empty"},
{"tharsis.prof.ranges.ZoneRange.save" : "tharsis/prof/ranges/ZoneRange.html#save"},
{"tharsis.prof.ranges.eventRange" : "tharsis/prof/ranges.html#eventRange"},
{"tharsis.prof.ranges.EventRange" : "tharsis/prof/ranges/EventRange.html"},
{"tharsis.prof.ranges.EventRange.profileData_" : "tharsis/prof/ranges/EventRange.html#profileData_"},
{"tharsis.prof.ranges.EventRange.this" : "tharsis/prof/ranges/EventRange.html#this"},
{"tharsis.prof.ranges.EventRange.front" : "tharsis/prof/ranges/EventRange.html#front"},
{"tharsis.prof.ranges.EventRange.popFront" : "tharsis/prof/ranges/EventRange.html#popFront"},
{"tharsis.prof.ranges.EventRange.empty" : "tharsis/prof/ranges/EventRange.html#empty"},
{"tharsis.prof.ranges.EventRange.save" : "tharsis/prof/ranges/EventRange.html#save"},
{"tharsis.prof.ranges.EventRange.bytesLeft" : "tharsis/prof/ranges/EventRange.html#bytesLeft"},
{"tharsis.prof" : "tharsis/prof.html"},
];
function search(str) {
	var re = new RegExp(str.toLowerCase());
	var ret = {};
	for (var i = 0; i < items.length; i++) {
		var k = Object.keys(items[i])[0];
		if (re.test(k.toLowerCase()))
			ret[k] = items[i][k];
	}
	return ret;
}

function searchSubmit(value, event) {
	console.log("searchSubmit");
	var resultTable = document.getElementById("results");
	while (resultTable.firstChild)
		resultTable.removeChild(resultTable.firstChild);
	if (value === "" || event.keyCode == 27) {
		resultTable.style.display = "none";
		return;
	}
	resultTable.style.display = "block";
	var results = search(value);
	var keys = Object.keys(results);
	if (keys.length === 0) {
		var row = resultTable.insertRow();
		var td = document.createElement("td");
		var node = document.createTextNode("No results");
		td.appendChild(node);
		row.appendChild(td);
		return;
	}
	for (var i = 0; i < keys.length; i++) {
		var k = keys[i];
		var v = results[keys[i]];
		var link = document.createElement("a");
		link.href = v;
		link.textContent = k;
		link.attributes.id = "link" + i;
		var row = resultTable.insertRow();
		row.appendChild(link);
	}
}

function hideSearchResults(event) {
	if (event.keyCode != 27)
		return;
	var resultTable = document.getElementById("results");
	while (resultTable.firstChild)
		resultTable.removeChild(resultTable.firstChild);
	resultTable.style.display = "none";
}

