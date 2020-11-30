function getDetails(settingsId)
    local server_settings = getElementData(resourceRoot, "server_settings")
	if server_settings[settingsId] then
		return server_settings[settingsId]
    end
    return ""
end