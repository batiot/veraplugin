module("L_Firebase1", package.seeall)

local ltn12 = require('ltn12')
local https = require('ssl.https')
local json = require("JSON")

-- Service ID strings used by this device.
SERVICE_ID = "urn:schemas-firebase-com:serviceId:Firebase1"
SENSOR_FIREBASE_LOG_NAME = "Firebase plugin: "

local DEBUG = false
local DEVICE_ID

local firebaseUrl = "projectid.firebaseio.com"
local firebaseKey = "a9crZqX1nLuynYPWyImY6MdRdfN5XHL548LGP2OS"

local deviceIdToCode = {}
local urnToTypeTab = {}

-- ------------------------------------------------------------------
--
-- ------------------------------------------------------------------
local function debug(s)
	if (DEBUG) then
		luup.log(SENSOR_FIREBASE_LOG_NAME .. " " .. s, 1)
	end
end
-- ------------------------------------------------------------------
--
-- ------------------------------------------------------------------
local function log(text, level)
	luup.log(SENSOR_FIREBASE_LOG_NAME .. " " .. text, (level or 50))
end
-- ------------------------------------------------------------------
--
-- ------------------------------------------------------------------
local function isempty(s)
  return s == nil or s == ''
end
-- ------------------------------------------------------------------
-- put FirebaseData
-- ------------------------------------------------------------------
function saveData(url,request_body)
  -- 5 Second timeout
  --socket.http.TIMEOUT = 15

  local response_body = {}

  local client, code, headers, status = https.request{
      url = url,
      method = "PATCH",
      headers = {
        ["Accept"] = "*/*",
        ["Content-Length"] = string.len(request_body),
        ["Content-Type"] = "application/x-www-form-urlencoded"
      },
      source = ltn12.source.string(request_body),
      sink = ltn12.sink.table(response_body),
      protocol = "tlsv1"
  }
  --print=silent
  ---- get body as string by concatenating table filled by sink
  response_body = table.concat(response_body)
  debug("http status: " .. " " .. status)
  debug("http body: " .. " " .. response_body)
end
-- ------------------------------------------------------------------
-- retrieve FirebaseData
-- ------------------------------------------------------------------
function retrieveData(url)
  -- 5 Second timeout
  --socket.http.TIMEOUT = 15
  local response_body = {}
  local client, code, headers, status = https.request{
      url = url,
      method = "GET",
      headers = {
        ["Accept"] = "*/*"
      },
      sink = ltn12.sink.table(response_body),
      protocol = "tlsv1"
  }
  --- get body as string by concatenating table filled by sink
  response_body = table.concat(response_body)
  --luup.log("http code: " .. " " .. code, 1)
  --luup.log("response_body: " .. " " .. response_body, 1)
	return json:decode(response_body)
end
-- ------------------------------------------------------------------
--
-- ------------------------------------------------------------------
function sleep(n)
  os.execute("sleep " .. tonumber(n))
end
-- ------------------------------------------------------------------
-- Callback Watch Configured Variables
-- ------------------------------------------------------------------
function watchVariableFirebase(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
	log("######" .. "Device: " .. lul_device .. " Service: " .. lul_service .." Variable: " .. lul_variable .. " Value " .. lul_value_old .. " => " .. lul_value_new, 6)
	-- /things/<type_code>/<device_code>/tstamp {value , deviceId}
	local currentTypeCode = urnToTypeTab[lul_service]
	local currentDeviceCode	= deviceIdToCode[lul_device]
	--debug("currentTypeCode: " .. currentTypeCode)
	--for a,b in pairs(deviceIdToCode) do
	--   luup.log("ZZZZ " .. a  .. " - " .. b, 1)
	--end
	--debug("currentDeviceCode: "  .. currentDeviceCode)
	--for typeKey,typeValue in pairs(typeTab) do
	--	if lul_service == typeValue['urn'] then
				--luup.log("type label: " .. " " .. typeValue['label'], 1)
	--			currentTypeCode = typeKey
	--	end
	--end
	local url = "https://projectid.firebaseio.com/things/".. currentTypeCode.. "/" .. currentDeviceCode ..".json?auth=a9crZqX1nLuynYPWyImY6MdRdfN5XHL548LGP2OS"
	local dataToSave = '{"' .. os.time() .. '":{"' .. lul_variable .. '":' .. lul_value_new .. '}}'
	debug("url: " .. " " .. url)
	debug("dataToSave: " .. " " .. dataToSave)
	saveData(url,dataToSave)
end


function initWatch(lul_device)
	DEVICE_ID = lul_device

	log("Initialising Firebase")

	package.loaded.JSON = nil
	json = require("JSON")

	_G.watchVariableFirebase = watchVariableFirebase

	-- "Interface device http://wiki.micasaverde.com/index.php/Luup_Device_Categories
	--luup.attr_set("category_num", 3, DEVICE_ID)

	--Reading variables
	firebaseUrl = luup.variable_get(SERVICE_ID, "firebaseUrl", DEVICE_ID)
	if(firebaseUrl == nil) then
		firebaseUrl = "fake.firebaseio.com"
		luup.variable_set(SERVICE_ID, "firebaseUrl", firebaseUrl, DEVICE_ID)
	end

	--Reading variables
	firebaseKey = luup.variable_get(SERVICE_ID, "firebaseKey", DEVICE_ID)
	if(firebaseKey == nil) then
		firebaseKey = "fakekey"
		luup.variable_set(SERVICE_ID, "firebaseKey", firebaseKey, DEVICE_ID)
	end

-- ------------------------------------------------------------------
-- registerWatches
-- ------------------------------------------------------------------
		local urlTypes = 'https://projectid.firebaseio.com/things/types.json?auth=a9crZqX1nLuynYPWyImY6MdRdfN5XHL548LGP2OS'
		local typeTab = retrieveData(urlTypes)
		--local urlMetas = 'https://projectid.firebaseio.com/things/metas.json?auth=a9crZqX1nLuynYPWyImY6MdRdfN5XHL548LGP2OS'
		--local metaTab = retrieveData(urlMetas)

		for deviceNo,device in pairs(luup.devices) do
			--we only watch device that have a configured type as urn
			for typeKey,typeValue in pairs(typeTab) do
				if device.device_type == typeValue['urn'] then
		      			if not isempty(device.mac) then
						debug("deviceNo: " .. deviceNo .. " device.mac:lower()  " .. device.mac:lower() .. " --- "..device.description )
						urnToTypeTab[typeValue['type']] = typeKey
						deviceIdToCode[deviceNo] = device.mac:lower()
						for varKey,varValue in pairs(typeValue['variables']) do
								--debug("                variables: " .. varValue .. "  " .. typeValue['type'])
								--valget = luup.variable_get(typeValue['type'], varValue, deviceNo)
								--if not isempty(valget) then
								--	log("                value: " .. valget)
									--watchVariableFirebase(deviceNo, typeValue['type'], varValue, 0, valget)
								--end
								luup.variable_watch("watchVariableFirebase", typeValue['type'], varValue, deviceNo)
						end
		      			end
				end
			end
		end
	log("Init Successful!" )
	return true, "Init successful.", "Firebase Plugin"
end
