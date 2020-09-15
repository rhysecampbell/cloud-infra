
// check for symbol
function isSymbolTA(symbol) {
   var retVal = false;

   if ('01' === symbol || 'essAirTemperature.1' === symbol) {
      retVal = true;
   }

   return retVal;
}

function isSymbolDP(symbol) {
   var retVal = false;
   
   if ('03' === symbol || 'essDewpointTemp.0' === symbol) {
      retVal = true;
   }

return retVal;
}

function isSymbolSurfT(symbol) {
   var retVal = false;

   if ('30' === symbol || '60' === symbol || 'spectroSurfaceTemperature.1' === symbol || 'essSurfaceTemperature.1' === symbol) {
      retVal = true;
   }

   return retVal;
}


function Combo(obs) {
    this.obs = obs;  
}
  
// they are all temperature now!     
function Observation(obs,type) {
    this.obs = obs;  
    this.type = type;
}


/* ----------------------------------------------------------- */

Combo.prototype.findObsEnd = function(endVal) {

   for(var loop=0;loop<this.obs.length;loop++) {
      if(isNaN(this.obs[loop].rh)) {
          endVal = loop;
      }
   }     
}

Combo.prototype.checkExtentAT = function ( y1, data ) {
    var min, max;   
    var atMax = d3.max(data, function(d) { return d.at; });
    var atMin = d3.min(data, function(d) { return d.at; });
    var atFCMax = d3.max(data, function(d) { return d.atFC; });
    var atFCMin = d3.min(data, function(d) { return d.atFC; });
      
    if(atMin < atFCMin) min = atMin; else min = atFCMin;
    if(atMax > atFCMax) max = atMax; else max = atFCMax;
    y1.domain([min - 2,max +2]);
}	


Combo.prototype.drawGrid = function (svg, width, y1) {
    svg.selectAll("line.horizontalGrid").data(y1.ticks(9)).enter()
    .append("line")
        .attr(
        {
            "class":"horizontalGrid",
            "x1" : 0,
            "x2" : width,
            "y1" : function(d){ return y1(d);},
            "y2" : function(d){ return y1(d);},
            "fill" : "none",
            "shape-rendering" : "crispEdges",
            "stroke-dasharray" : "2,2",
            "stroke" : "grey",
            "stroke-width" : "1px"
        });   
}
  
//DEPRECATED 
Combo.prototype.appendTips = function (data, margin, width,x,yRH,yAT,myDiv) {
    
  var rhObsTip = d3.tip()
         .attr('class', 'd3-rh-combo-tip')
         .html(function(d) { 
             var dFormat = d3.time.format("%x %H:%M");                   
             return "RH: " + d.rh + "&#37;<br/><HR/>" 
                     + dFormat(new Date(d.date));
          });  
    
  var airObsTip = d3.tip()
         .attr('class', 'd3-air-combo-tip')
         .html(function(d) { 
             var dFormat = d3.time.format("%x %H:%M");
             return "AirT : " + d3.round(d.at,1) + "&#176;"+tempChar+"<br/><HR/>"
                     + dFormat(new Date(d.date)); 
         });   
 
  var airFCtip = d3.tip()
         .attr('class', 'd3-fc-air-combo-tip')
         .html(function(d) { 
             var dFormat = d3.time.format("%x %H:%M");
             return "Forecast AirT : " + d3.round(d.atFC,1) + "&#176;"+tempChar+"<br/><HR/>"
                     + dFormat(new Date(d.date)); 
         });         
 
   var rhFCtip = d3.tip()
         .attr('class', 'd3-fc-rh-combo-tip')
      //   .offset(0.1)
         .html(function(d) { 
             var dFormat = d3.time.format("%x %H:%M");                   
             return "Forecast RH: " + d.rhFC + "&#37;<br/><HR/>" 
                     + dFormat(new Date(d.date));
          });     
  
  rhObsTip.offset([-8,0]);
  var visRH = d3.select(myDiv).selectAll("svg").append('svg').call(rhObsTip);
  visRH.selectAll('rect')
  .data(data)
  .enter().append('rect')
  .attr('width', width/data.length)
  .attr('height', function(d) { return  8; })
  .attr('y', function(d) { if(isNaN(yRH(d.rh)) === true) return -10;
	                       else return yRH(d.rh) + margin.top; })
  .attr('x', function(d) { return x(d.date) + margin.left - 4; })

  .attr('fill-opacity','0.0')
  .on('mouseover', rhObsTip.show)
  .on('mouseout', rhObsTip.hide); 
  
    
  airObsTip.offset([-8,0]);
  var visAT = d3.select(myDiv).selectAll("svg").append('svg').call(airObsTip);
  visAT.selectAll('rect')
  .data(data)
  .enter().append('rect')
  .attr('width', width/data.length)
  .attr('height', function(d) { return  8; })
  .attr('y', function(d) { if(isNaN(yAT(d.at)) === true) return -10;
	                       else return yAT(d.at) + margin.top; })
  .attr('x', function(d) { return x(d.date) + margin.left - 4; })

  .attr('fill-opacity','0.0')
  .on('mouseover', airObsTip.show)
  .on('mouseout', airObsTip.hide);  
  
  
  airFCtip.offset([-8,0]);
  var visATFC = d3.select(myDiv).selectAll("svg").append('svg').call(airFCtip);
  visATFC.selectAll('rect')
  .data(data)
  .enter().append('rect')
  .attr('width', 10) //width/data.length)
  .attr('height', function(d) { return  8; })
  .attr('y', function(d) { if(isNaN(yAT(d.atFC)) === true) return -10;
	                       else return yAT(d.atFC) + margin.top; })
  .attr('x', function(d) { return x(d.date) + margin.left - 4; })
  .attr("fill","lightgrey")
  .attr('fill-opacity','0.0')
  .on('mouseover', airFCtip.show)
  .on('mouseout', airFCtip.hide);  
  
  rhFCtip.offset([-8,0]);
  var visRHFC = d3.select(myDiv).selectAll("svg").append('svg').call(rhFCtip);
  visRHFC.selectAll('rect')
  .data(data)
  .enter().append('rect')
  .attr('width', 10) //width/data.length)
  .attr('height', function(d) { return  8; })
  .attr('y', function(d) { if(isNaN(yRH(d.rhFC)) === true) return -10;
	                       else return yRH(d.rhFC) + margin.top; })
  .attr('x', function(d) { return x(d.date) + margin.left - 4; })
  .attr("fill","lightgrey")
  .attr('fill-opacity','0.0')
  .on('mouseover', rhFCtip.show)
  .on('mouseout', rhFCtip.hide);  
    
}   

Combo.prototype.appendAxis = function(svg,xAxis,yAxisLeft,width,height) {
  
  svg.append("g")
      .attr("class", "x axis")
      .attr("transform", "translate(0," + (height + 1) + ")")
      .call(xAxis)
      .selectAll("text")  
         .style("text-anchor", "end")
         .attr("dx", "-.8em")
         .attr("dy", ".15em")
         .attr("transform", function(d) {
              return "rotate(-45)";
          });


   svg.append("g")
      .attr("class", "y axis")
      .attr("transform", "translate(" + width + ",0)")
       .style("fill","black")
      .call(yAxisLeft)
    .append("text")
      .attr("transform", "rotate(-90)")
      .attr("y", +30)
      .attr("dy", ".71em")
      .style("text-anchor", "end")
      .style("fill","black")
      .text("Air Temperature -- Forecast Air Temperature º" + tempChar); 
     //  .text("Relative Humidity -- Forecast Relative Humidity");   
    
}

//DEPRECATED
Combo.prototype.appendPath = function(svg, data, lineAT, lineST, lineDP,
                                      lineFunction, lineData, outLine) {

  // air temp line
  svg.append("path")
      .datum(data)
      .attr("class", "lineAT")
      .attr("d", lineAT);    

var lineGraph = svg.append("path")
     .attr("d", lineFunction(lineData))
     .attr("stroke", "blue")
     .attr("stroke-width", 1)
     .attr("opacity", "0.6")
     .attr("fill", "none");
     
var graphBorder = svg.append("path")
     .attr("d", lineFunction(outLine))
     .attr("stroke", "darkgrey")
     .attr("stroke-width", 6)
     .attr("opacity", "1")
     .attr("fill", "none");
      
}
 
Combo.prototype.dp = function (svg,width,height,xpos) {
    var myY = height;
    var myX = width;
    var mySpace;
    var barWidth = 8;
    var loop;
    var mp;
    var angle = 250;
    var gap = 14;
    
    // draw diagonal bars
    for(loop = -120;loop < width; loop+=gap) {
       mySpace = loop + barWidth;
       mp = loop + "," + myY + ", " + (mySpace+angle) + "," + 0 + ", " ;
       mp = mp + (mySpace+angle+barWidth) + "," + 0 + ", ";
       mp = mp + (mySpace) + "," +myY;
       svg.append("polygon")       // attach a polygon
     //     .style("stroke", "black")  // colour the line
          .style("fill", "lightgrey")     // set bar colour
          .style("opacity", "0.4")
          .attr("points", mp);  // x,y points 
    }
    

   // remove lines from front of graph
   mp = "-50,0, -50," + height + ", " + xpos + ",";
   mp = mp + height + ", " + xpos + ",0";
    svg.append("polygon")       // attach a polygon
//    .style("stroke", "black")  // colour the line
    .style("fill", "white")     // set background to white
    .attr("points", mp);  // x,y points 

   // trim bar over writes 
   mp = width + "," +"-3, " + width + "," + (height+3) + ", ";
   mp = mp + (width+60) + "," + (height+3) + ",";
   mp = mp + (width+60) + ",-3";
   svg.append("polygon")       // attach a polygon
   // .style("stroke", "black")  // colour the line
    .style("fill", "white")     // set background to white
    .attr("points", mp);  // x,y points 
    
//   svg.append("circle")
//   .attr("cx", 0)
//   .attr("cy", -10)
//   .attr("r", 5)
//   .style("fill", "#786884");
   
//    svg.append("circle")
//   .attr("cx", width )
//   .attr("cy", -10)
//   .attr("r", 5)
//   .style("fill", "#0570BD");
    
}   
   
   
Combo.prototype.drawGraph = function(myDiv, title) { 
 
var customTimeFormat = d3.time.format.multi([
  [".%L", function(d) { return d.getMilliseconds(); }],
  [":%S", function(d) { return d.getSeconds(); }],
  ["%I:%M", function(d) { return d.getMinutes(); }],
  ["%I %p", function(d) { return d.getHours(); }],
  ["%b %d", function(d) { return d.getDay() && d.getDate() !== 1; }],
  ["%b %d", function(d) { return d.getDate() !== 1; }],
  ["%B", function(d) { return d.getMonth(); }],
  ["%Y", function() { return true; }]
]);    

var margin = {top: 30, right: 50, bottom: 50, left: 50},
    width = glWidth - margin.left - margin.right,
    height = glHeight - margin.top - margin.bottom;

  var x = d3.time.scale().range([0, width]);
  var yAT = d3.scale.linear().range([height, 0]);  

  var xAxis = d3.svg.axis().scale(x).orient("bottom");
  xAxis.ticks(12).tickFormat(customTimeFormat);

  var yAxisLeft = d3.svg.axis().scale(yAT).orient("right").ticks(5);

   // DEPRECATED 
   var lineAT = d3.svg.line()
    .x(function(d) { return x(d.date); })
    .y(function(d) { return yAT(d.at); })
    .defined(function(d) {return !isNaN(d.at);});    
  
  var lineST =  d3.svg.line()
    .x(function(d) { return x(d.date); })
    .y(function(d) { return yAT(d.at); })
    .defined(function(d) {return !isNaN(d.at);});
  
  var lineDP = d3.svg.line()
    .x(function(d) { return x(d.date); })
    .y(function(d) { return yAT(d.dp); })
    .defined(function(d) {return !isNaN(d.dp);});
  
  var lineFunction = d3.svg.line()
    .x(function(d) { return d.x; })
    .y(function(d) { return d.y; })
    .interpolate("linear");    
    
  var svg = d3.selectAll(myDiv).append("svg")
    .attr("width", width + margin.left + margin.right)
    .attr("height", height + margin.top + margin.bottom)
    .append("g")
    .attr("transform", "translate(" + margin.left + "," + margin.top + ")");
     
  var data = this.obs;
  
  var maxTime = 0;
  var minTime = new Date().getTime() + 10000000000;

  for(var loop=0;loop<data.length;loop++) {
     if(maxTime < data[loop].date.getTime()) maxTime = data[loop].date.getTime();
     if(minTime > data[loop].date.getTime()) minTime = data[loop].date.getTime();    
  }

  var workTime = (maxTime - minTime) / data.length;
  var indexTime = (new Date().getTime() - minTime) / workTime; 
  var myXpos = (width/data.length) * indexTime;
  if(myXpos > width) myXpos = width;        // trap funny values

  var lineData = [ { "x": myXpos,   "y": 0},  { "x": myXpos,  "y": height}];
  
  var outLine = [ {"x": 0 - margin.left, "y": - margin.top}, 
                  {"x": 0 - margin.left, "y": height + margin.bottom},
                  {"x": width + margin.right, "y":  height + margin.bottom}, 
                  {"x": width + margin.right, "y": - margin.top},
                  {"x": 0 - margin.left, "y": - margin.top}];
  
  var endVal;
  
  this.findObsEnd(endVal);
  
  x.domain(d3.extent(data, function(d) { return d.date; }));

  this.checkExtent(yAT,data);

  this.dp(svg,width,height,myXpos);
    
  this.appendTips(data,margin,width,x,yAT,myDiv);

  this.appendAxis(svg,xAxis,yAxisLeft,width,height);
  
  this.appendPath(svg,data,   lineAT,lineST,lineDP,lineFunction,lineData,outLine);

  this.drawGrid(svg,width,yAT);
      
}

/* ------- End of Combo class methods -------------------------- */

Observation.prototype.findObsEnd = function(endVal) {

   for(var loop=0;loop<this.obs.length;loop++) {
      if(isNaN(this.obs[loop].rh)) {
          endVal = loop;
      }
   }     
   endVal = (new Date()).getTime();
}

// now that we display temps only,
// check the max of all the properties
Observation.prototype.checkYAxisExtent = function ( y1, data ) {
    var min, max;   
    
    var atMax = d3.max(data, function(d) { return d.at; });
    var atMin = d3.min(data, function(d) { return d.at; });
    
    var stMax = d3.max(data, function(d) { return d.st; });
    var stMin = d3.min(data, function(d) { return d.st; });

    var dpMax = d3.max(data, function(d) { return d.dp; });
    var dpMin = d3.min(data, function(d) { return d.dp; });

    // and fix
    atMax = isNaN(atMax) ? 0 : atMax;
    atMin = isNaN(atMin) ? 0 : atMin;
    stMax = isNaN(stMax) ? 0 : stMax;
    stMin = isNaN(stMin) ? 0 : stMin;
    dpMax = isNaN(dpMax) ? 0 : dpMax;
    dpMin = isNaN(dpMin) ? 0 : dpMin;

    // and compare...
    var tempMax = Math.max(atMax, stMax, dpMax);
    var tempMin = Math.min(atMin, stMin, dpMin);

    console.log(" Graph Max,Min", tempMax, tempMin);

    y1.domain([tempMin - 2, tempMax +2]);
}	

Observation.prototype.checkXAxisExtent = function ( x1, data ) {

   var retVal = true;  // extent represent data

   var dateMax = d3.max(data, function(d) { return d.date; });
   var dateMin = d3.min(data, function(d) { return d.date; });

   // wait, ensure 24-hour graph
   if (dateMax!=null) {

      var twentyFourHoursBeforeMax = new Date(
          dateMax.getFullYear(),
          dateMax.getMonth(),
          dateMax.getDate(),
          dateMax.getHours() - 23 ,
          dateMax.getMinutes(),
          dateMax.getSeconds(),
          dateMax.getMilliseconds()
      );

console.log("Data date min, max", dateMin, dateMax);      
console.log("date Max, 24 hours prior" , dateMax, twentyFourHoursBeforeMax);

      if (dateMin==null || twentyFourHoursBeforeMax.getTime()  < dateMin.getTime() ) {
          dateMin = twentyFourHoursBeforeMax;
          retVal = false; // we 'fixed' the x axis
      }
   }

   console.log("Date data min/max", dateMin, dateMax);

   x1.domain([dateMin, dateMax]);

   return retVal;

}

Observation.prototype.drawGrid = function (svg, width, y1) {
    svg.selectAll("line.horizontalGrid").data(y1.ticks(9)).enter()
    .append("line")
        .attr(
        {
            "class":"horizontalGrid",
            "x1" : 0,
            "x2" : width,
            "y1" : function(d){ return y1(d);},
            "y2" : function(d){ return y1(d);},
            "fill" : "none",
            "shape-rendering" : "crispEdges",
            "stroke-dasharray" : "2,2",
            "stroke" : "grey",
            "stroke-width" : "1px"
        });   
}
  
Observation.prototype.appendTips = function (data, margin, width,x,yAT,myDiv) {
  
  var tipWidth =  (width/data.length > 10) ? 10 :  width/data.length; 

  var airObsTip = d3.tip()
         .attr('class', "d3-air-tip")
         .html(function(d) { 
             var dFormat = d3.time.format("%x %H:%M");
             return "Air Temp: " + d3.round(d.at,1) + "&#176;"+tempChar+"<br/><HR/>"
                     + dFormat(new Date(d.date)); 
         });   
  airObsTip.offset([-8,0]);

  var roadObsTip = d3.tip()
         .attr('class', "d3-surf-tip")
         .html(function(d) {
             var dFormat = d3.time.format("%x %H:%M");
             return "Surf Temp: " + d3.round(d.st,1) + "&#176;"+tempChar+"<br/><HR/>"
                     + dFormat(new Date(d.date));
         });
  roadObsTip.offset([-8,0]);

  var dpObsTip = d3.tip()
         .attr('class', "d3-dp-tip")
         .html(function(d) {
             var dFormat = d3.time.format("%x %H:%M");
             return "Dew: " + d3.round(d.dp,1) + "&#176;"+tempChar+"<br/><HR/>"
                     + dFormat(new Date(d.date));
         });
  dpObsTip.offset([-8,0]);


  var visAT = d3.select(myDiv).selectAll("svg").append('svg').call(airObsTip);
  visAT.selectAll('rect')
  .data(data)
  .enter().append('rect')
  .attr('width', tipWidth)
  .attr('height', function(d) { return  8; })
  .attr('y', function(d) { if(isNaN(yAT(d.at)) === true) return -10;
	                       else return yAT(d.at) + margin.top; })
  .attr('x', function(d) { return x(d.date) + margin.left - 4; })

  .attr('fill-opacity','0.0')
  .on('mouseover', airObsTip.show)
  .on('mouseout', airObsTip.hide);  
      
  var visST = d3.select(myDiv).selectAll("svg").append('svg').call(roadObsTip);
  visST.selectAll('rect')
  .data(data)
  .enter().append('rect')
  .attr('width', tipWidth)
  .attr('height', function(d) { return  8; })
  .attr('y', function(d) { if(isNaN(yAT(d.st)) === true) return -10;
                               else return yAT(d.st) + margin.top; })
  .attr('x', function(d) { return x(d.date) + margin.left - 4; })

  .attr('fill-opacity','0.0')
  .on('mouseover', roadObsTip.show)
  .on('mouseout', roadObsTip.hide);

  var visDP = d3.select(myDiv).selectAll("svg").append('svg').call(dpObsTip);
  visDP.selectAll('rect')
  .data(data)
  .enter().append('rect')
  .attr('width', tipWidth)
  .attr('height', function(d) { return  8; })
  .attr('y', function(d) { if(isNaN(yAT(d.dp)) === true) return -10;
                               else return yAT(d.dp) + margin.top; })
  .attr('x', function(d) { return x(d.date) + margin.left - 4; })

  .attr('fill-opacity','0.0')
  .on('mouseover', dpObsTip.show)
  .on('mouseout', dpObsTip.hide);


}   

Observation.prototype.appendAxis = function(svg,xAxis,yAxisLeft,width,height) {
  
  svg.append("g")
      .attr("class", "x axis")
      .attr("transform", "translate(0," + (height + 1) + ")")
      .call(xAxis)
      .selectAll("text")  
         .style("text-anchor", "end")
         .attr("dx", "-.8em")
         .attr("dy", ".15em")
         .attr("transform", function(d) {
              return "rotate(-45)";
          });

   // left axis only temp
   svg.append("g")
      .attr("class", "y axis")
      .attr("transform", "translate(0,0") //" + width + ",0)")
      .call(yAxisLeft)
    .append("text")
      .attr("transform", "rotate(-90)")
      .attr("y", -38)
      .attr("dy", ".71em")
      .style("text-anchor", "end")
        .text("Temperature " + tempChar);
}

Observation.prototype.appendPath = function(svg,data,lineAT, lineST, lineDP, 
                                   width,lineFunction,outLine) {

  svg.append("path")
      .datum(data)
      .attr("class", "lineAT")
      .attr("d", lineAT);

  svg.append("path")
      .datum(data)
      .attr("class", "lineST")
      .attr("d", lineST);

  svg.append("path")
      .datum(data)
      .attr("class", "lineDP")
      .attr("d", lineDP);

//   svg.append("circle")
//   .attr("cx", 0)
//   .attr("cy", -10)
//   .attr("r", 5)
//   .style("fill", "#786884");
   
//    svg.append("circle")
//   .attr("cx", width )
//   .attr("cy", -10)
//   .attr("r", 5)
//   .style("fill", "#0570BD");
   
  var graphBorder = svg.append("path")
     .attr("d", lineFunction(outLine))
     .attr("stroke", "darkgrey")
     .attr("stroke-width", 6)
     .attr("opacity", "1")
     .attr("fill", "none"); 
   
}
 

Observation.prototype.drawGraph = function(myDiv, title) { 
    

var customTimeFormat = d3.time.format.multi([
  [".%L", function(d) { return d.getMilliseconds(); }],
  [":%S", function(d) { return d.getSeconds(); }],
  ["%I:%M", function(d) { return d.getMinutes(); }],
  ["%I %p", function(d) { return d.getHours(); }],
  ["%b %d", function(d) { return d.getDay() && d.getDate() !== 1; }],
  ["%b %d", function(d) { return d.getDate() !== 1; }],
  ["%B", function(d) { return d.getMonth(); }],
  ["%Y", function() { return true; }]
]);


var margin = {top: 30, right: 50, bottom: 50, left: 50},
    width = glWidth - margin.left - margin.right,
    height = glHeight - margin.top - margin.bottom;

var x = d3.time.scale().range([0, width]);

var yAT = d3.scale.linear().range([height, 0]);  

var xAxis = d3.svg.axis().scale(x).orient("bottom");

xAxis.ticks(12).tickFormat(customTimeFormat);

var yAxisLeft = d3.svg.axis().scale(yAT).orient("left").ticks(5);

var lineAT = d3.svg.line()
    .x(function(d) { return x(d.date); })
    .y(function(d) { return yAT(d.at); })
    .defined(function(d) {return !isNaN(d.at);});    
    
var lineST = d3.svg.line()
    .x(function(d) { return x(d.date); })
    .y(function(d) { return yAT(d.st); })
    .defined(function(d) {return !isNaN(d.st);});

var lineDP = d3.svg.line()
    .x(function(d) { return x(d.date); })
    .y(function(d) { return yAT(d.dp); })
    .defined(function(d) {return !isNaN(d.dp);});

var svg = d3.selectAll(myDiv).append("svg")
    .attr("width", width + margin.left + margin.right)
    .attr("height", height + margin.top + margin.bottom)
    .append("g")
    .attr("transform", "translate(" + margin.left + "," + margin.top + ")");
     
  var data = this.obs;
  
  var bisectDate = d3.bisector(function(d) { return d.date; }).left; 

  var myIndex = bisectDate(data, new Date().getTime());

  var myXpos = (width/data.length) * myIndex;
  
  var endVal=null;
  
  var lineFunction = d3.svg.line()
    .x(function(d) { return d.x; })
    .y(function(d) { return d.y; })
    .interpolate("linear");    
  
  var outLine = [ {"x": 0 - margin.left, "y": - margin.top}, 
                  {"x": 0 - margin.left, "y": height + margin.bottom},
                  {"x": width + margin.right, "y":  height + margin.bottom}, 
                  {"x": width + margin.right, "y": - margin.top},
                  {"x": 0 - margin.left, "y": - margin.top}];
  
  var xAxisRepresentsData = this.checkXAxisExtent(x, data);
  this.checkYAxisExtent(yAT, data);

  this.appendTips(data,margin,width,x,yAT,myDiv);

  this.appendAxis(svg,xAxis,yAxisLeft,width,height);
  
  this.appendPath(svg,data, lineAT, lineST, lineDP, width, lineFunction, outLine);

  this.drawGrid(svg,width,yAT);  

  var chartTitle = title!=null ? title : "";
  if (obs==null || obs.length<1) {
        chartTitle += ": No data for specified time period";
  }
  if (!xAxisRepresentsData) {
        chartTitle += " (Data missing)";
  }

  svg.append("text")
        .attr("x", (width / 2))
        .attr("y", 0)
        .attr("text-anchor", "middle")
        .style("font-size", "16px")
        .style("text-decoration", "underline")
        .text(chartTitle);
}

/* -----------------Helpers functions  ---------------------------------- */

         function obsFN(rb) {
        //     if(rb.checked==true) return;
             document.getElementById('fc_id').checked = false;
             document.getElementById('combo_id').checked = false;
             document.getElementById('chartContainer').innerHTML = "";
             sensorObs.drawGraph("#chartContainer", "Observation");
          };

          function forecastFN(rb) {
       //      if(rb.checked==true) return;
             document.getElementById('obs_id').checked = false;
             document.getElementById('combo_id').checked = false;     
             document.getElementById('chartContainer').innerHTML = "";
             sensorFC.drawGraph("#chartContainer", "Forecast");
          };

          function comboFN(rb) {
       //      if(rb.checked==true) return;
//             document.getElementById('obs_id').checked = false;
//             document.getElementById('fc_id').checked = false;
             document.getElementById('chartContainer').innerHTML = "";  
             combo.drawGraph("#chartContainer", "Combo");
          };

   function showBanner(myText) {
            document.getElementById("chartContainer").style.display="none"; 
            document.getElementById("legend").style.display="none";
            document.getElementById("banner").style.display="block";
            document.getElementById("banner").innerHTML = myText; 
   }

   function showContent() {
              document.getElementById("chartContainer").style.display="block"; 
       //     document.getElementById("banner").style.display="block"; 
       //     document.getElementById("chartContainer").style.background-color="white"; 
     //       document.getElementById("control").style.display="none"; 
       //     document.getElementById("info").innerHTML = myText; 
   }

   function getParam( name ){
      name = name.replace(/[\[]/,"\\\[").replace(/[\]]/,"\\\]");  
      var regexS = "[\\?&]"+name+"=([^&#]*)";  
      var regex = new RegExp( regexS );  
      var results = regex.exec( window.location.href ); 
      if( results == null )    return "";  
          else    return results[1];
   }

  function myObs(time, atVal, stVal, dpVal) {
        this.date = time;
        this.at = atVal;
        this.st = stVal;
        this.dp = dpVal;
   };  
   
   function myFC(time,rhVal,atVal) {
        this.date = time;
        this.rh = NaN;
        this.at = NaN;
        this.rhFC = rhVal;
        this.atFC = atVal;
   };  
 

  function getEpoch(myTime) {
      return myTime / 1000;
  }

  function toFahr(value) {
     var retVal = null;
     if (value!=null) {
       retVal =((value / 5) * 9) + 32;
     }
     return retVal;
  }

  function parseObsDataset(dataset) {

    //console.log("Parsing dataset: " ,  dataset);

   //  console.log("--> " + sname + " --> " + st.time + " --> " + st.value);

  // OK ,the data is not organized by time
  // therefore, we get each reading separately in the list
  // unfortunately the graph IS organized by time
  // so do that work here

     var currDate = null; // nothing yet

     // prior readings - we'll collect as we go
     // when the time changes, we'll make that one observation with all readings
     var currAT = NaN;
     var currST = NaN;
     var currDP = NaN;
     var firstFoundSurfT;

     for( var loop=0; loop<dataset.results.length;loop++) {

         var reading = dataset.results[loop];
         var symbol = reading.symbol;
         var value = reading.value;
         var readingDate = reading.time;

         // push?
         if (currDate!=null) {
            // changed?
            if (currDate.getTime()!=readingDate.getTime()) {

                // REMOVE THIS TEST CODE
                if (isNaN(currDP) && !isNaN(currST)) {
                  // currDP = currST + 3;
                }

		// collect!
                //console.log("Pushing", currDate, currAT, currST, currDP);
                obs.push(new myObs(currDate, currAT, currST, currDP));

                // change!
                currDate = readingDate;
                currAT = NaN;
                currST = NaN;
                currDP = NaN;
            }
         }
	 else {
             // now we started!
             currDate = readingDate;
         }

	 // air temp
         if(isSymbolTA(symbol)) {
           currAT = (myUnits===1 ? toFahr(value) : value);
	 }
         // DP
         else if(isSymbolDP(symbol)) {
           currDP = (myUnits===1 ? toFahr(value) : value);
         }
         // ST
         else if(symbol === firstFoundSurfT || (!firstFoundSurfT && isSymbolSurfT(symbol))) {
           firstFoundSurfT = symbol
           currST = (myUnits===1 ? toFahr(value) : value);
         }
         else {
            console.log("WARNING: skipping reading", reading);
         }
     }
     
     // leftovers
     if (currDate!=null) {
        obs.push(new myObs(currDate, currAT, currST, currDP));
     }

     return;        
  }

 
  function myParseFC(dataset) {
     var st = dataset.results[0];
     var myDate, count = 0, out_t;
     
     stLat = dataset.lat;
     stLon = dataset.lon;
     stName = dataset.Name;
     
     for(var loop=0; loop<dataset.results.length;loop++) {
         st = dataset.results[loop];

         if(st.symbol === 'FAT') {
             myDate = st.time;
             if(myUnits === 1) out_t = ((st.value / 5) * 8) + 32; else out_t = st.value;
             fc.push(new myObs(myDate,NaN,out_t));
         }
      }
     for(var loop=0; loop<dataset.results.length;loop++) {
         st = dataset.results[loop];

         if(st.symbol === 'FRH') {
             fc[count].rh = st.value;
             count++;  
         }
     }
  }
  
  function drawCombo() {
   var loop;

   cm = obs.slice(0);
   
   for(loop=0;loop<fc.length;loop++) {
      cm.push(new myFC(fc[loop].date,fc[loop].rh,fc[loop].at)); 
   }  
 //  console.log(obs.length+" --> " + fc.length + " --> " + cm.length);
   combo = new Combo(cm);
  }

/* ------------------------------------------------- */

// this to be embedded in the 'onload function of the remote data request
function loadFcData() {
     var url = '/api/fcast/graph?lat='+myLat+'&lon='+myLon;

     var invocation = new XMLHttpRequest();
     invocation.timeout = 8000;

     if(invocation) {
        invocation.open('get', url, true);
        invocation.setRequestHeader('Content-Type', 'application/json');
           invocation.onreadystatechange = function () {
          //    invocation.onload = function (e) {
                 if (invocation.readyState == 4) {
                    if (invocation.status == 200 || 500 || 404) {
                       if(invocation.responseText.length < 100) {
                          document.getElementById("fc_id").disabled="true";
                          document.getElementById("combo_id").disabled="true";
                          document.getElementById("fc_txt").style.color="grey";
                          document.getElementById("combo_txt").style.color="grey";
                          return;
                       }
                       myDataFC = JSON.parse(invocation.responseText);
                       parseDate = d3.time.format.utc("%Y-%m-%d %H:%M:%S").parse;
                       myDataFC.results.forEach(function(d) {
                           d.time = parseDate(d.time);
                       })
                       myParseFC(myDataFC);
      
                       sensorFC = new Observation(fc, "forecast");
       
                          drawCombo();  
                    }
                    else {
                           console.log(invocation.statusText);
                    }
                 } 
         //    }
         };
         invocation.send(); 
     }
  
}

function loadFcData_old() {
    d3.json("fb-fcast.json", function(error, data) { // <-----------------
      parseDate = d3.time.format.utc("%Y-%m-%d %H:%M:%S").parse;
      data.results.forEach(function(d) {
        d.time = parseDate(d.time);
      });
       myParseFC(data);
      
      sensorFC = new Observation(fc ,"forecast");
       
       drawCombo();     
    });
  
}

// this to be embedded in the 'onload function of the remote data request

  function loadObsData(){
     var url = '/api/rwis/graph?stnid='+myStnId;
     var invocation = new XMLHttpRequest();
     if(invocation) { 
        invocation.open('get', url, true);
        invocation.setRequestHeader('Content-Type', 'application/json');
           invocation.onreadystatechange = function () { 
                 if (invocation.readyState == 4) {
                    if (invocation.status !=200) {
                       console.log(url, invocation);
                       showBanner("No Data");
                       //showBanner("Error contacting data server: " + url + " error: " + invocation.statusText );
		    }
                    else  {
                       if(invocation.responseText.length < 100) {
                          showBanner("Station ID [" + myStnId + "] has no current data"); 
                       }
                       myData = JSON.parse(invocation.responseText);
                       //console.log(JSON.stringify(myData));
                       // kinda dumb but go through every row here (and later)
                       // and parse the date
                       parseDate = d3.time.format.utc("%Y-%m-%d %H:%M:%S").parse;
                       myData.results.forEach(function(d) {
                           d.time = parseDate(d.time);
                       })
                       parseObsDataset(myData);
                       var stationName = myData.Name;// + " [" + myStnId + "]";
                       sensorObs = new Observation(obs, "observation");
                       sensorObs.drawGraph("#chartContainer", stationName);
                       document.getElementById("chartContainer").style.display="block";
                    } 
                 } 
         //    }
         };
         invocation.send(); 
     }
  }

function loadObsData_old() {
   d3.json("fb-obs.json", function(error, data) {  // <-------------------
       parseDate = d3.time.format("%Y-%m-%d %H:%M:%S").parse;
       data.results.forEach(function(d) {
          d.time = parseDate(d.time);
      });
      myParse(data);    
      sensorObs = new Observation(obs , "observation");
      sensorObs.drawGraph("#chartContainer", "old");
      document.getElementById("chartContainer").style.display="block";
      loadFcData();
  });
}

   function getParam( name ){
      name = name.replace(/[\[]/,"\\\[").replace(/[\]]/,"\\\]");  
      var regexS = "[\\?&]"+name+"=([^&#]*)";  
      var regex = new RegExp( regexS );  
      var results = regex.exec( window.location.href ); 
      if( results == null )    return "";  
          else    return results[1];
   }

/* -------------------- main ---------------------------------- */

/* some global variables */
var obs = [];
var fc = [];
var cm = []; 
var stLat;
var stlon;
var stName;

var glWidth = 784;
var glHeight = 410;

var sensorFC ;
var sensorObs;
var combo;
var tempChar;
var myUnits = 0 * 1;

var adjust_t = getParam( 'utc_offset' );
if(adjust_t === "") adjust_t = 0;
     else if(isNaN(adjust_t) === true) adjust_t = 0;
     
var urlUnits = getParam( 'units' );

if(urlUnits === "ISO") {
  	myUnits = 0;  
  	tempChar ='C'
}
else {
		myUnits = 1;
		tempChar = 'F';
}     
var myStnId = getParam( 'stnid' );

  //  myStnId = 4353;         // just while developing
    
     if(myStnId === '') {
         window.onload = function(){
           showBanner("Required Parameter missing: stnid"); 
         }
     }
     else {
        loadObsData();
     };



