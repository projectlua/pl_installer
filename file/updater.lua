local resourceFileCache = {}
local resourceName = getResourceName(getThisResource())
if resourceName == "installer" then return end
local cfgDir = "resource.cfg"

function backupResource()
    local meta = xmlLoadFile("meta.xml")
    local metaData = xmlNodeGetChildren(meta)
    if metaData then
        for index, node in ipairs(metaData) do
            local fileType = xmlNodeGetName(node)
            local fileLocation = xmlNodeGetAttribute(node, "src")
            if fileType == "script" or fileType == "file" or fileType == "config" or fileType == "map" or fileType == "html" then

                if fileExists("old/"..currentVersion.."/"..fileLocation) then
                    fileDelete("old/"..currentVersion.."/"..fileLocation)
                end
                fileCopy(fileLocation, "old/"..currentVersion.."/"..fileLocation)
            end
        end
    end
    xmlUnloadFile(meta)
end

function updateResource()
    local meta = xmlLoadFile("update-meta.xml")
    local metaData = xmlNodeGetChildren(meta)
    if metaData then
        for index, node in ipairs(metaData) do
            local fileType = xmlNodeGetName(node)
            local fileLocation = xmlNodeGetAttribute(node, "src")
            if fileType == "script" or fileType == "file" or fileType == "config" or fileType == "map" or fileType == "html" then
                resourceFileCache[#resourceFileCache + 1] = fileLocation
                if fileExists(fileLocation) then
                    fileDelete(fileLocation)
                end
            end
        end
    end
    xmlUnloadFile(meta)
    
    
    resourceFileCount = 1
    downloadFile()
end

function completeResource()
    fileDelete("meta.xml")
    local meta = xmlLoadFile("update-meta.xml")
    if meta then
        xmlCreateChild(meta, "oop").value = "true"
        local updaterChild = xmlCreateChild(meta, "script")
        updaterChild:setAttribute("src", "encode.lua")
        updaterChild:setAttribute("type", "server")
        
        local updaterChild = xmlCreateChild(meta, "script")
        updaterChild:setAttribute("src", "updater.lua")
        updaterChild:setAttribute("type", "server")

        xmlSaveFile(meta)
        xmlUnloadFile(meta)
    end

    if fileExists(cfgDir) then
        fileDelete(cfgDir)
    end
    local file = fileCreate(cfgDir)
    resourceData.version = newestVersion
    fileWrite(file, toJSON(resourceData))
    fileClose(file)

    fileRename("update-meta.xml", "meta.xml")
    restartResource(getThisResource())
end

function downloadFile()
    if not resourceFileCache[resourceFileCount] then
        completeResource()
        return
    end
    fetchRemote(apiDir..resourceName.."/"..resourceFileCache[resourceFileCount],
        function(data, err, path)
            if err == 0 then
                local size = 0
                if fileExists(path) then
                    fileDelete(path)
                end
                local file = fileCreate(path)
                fileWrite(file, data)
                fileClose(file)
            else
                print("projectlua/"..resourceName.."/"..path.." > download failed")
            end
            if resourceFileCache[resourceFileCount+1] then
                resourceFileCount = resourceFileCount + 1
                print("projectlua/"..resourceName.." > downloaded: "..path.."...")
                downloadFile()
            else
                completeResource()
            end
        end,
    "", false, resourceFileCache[resourceFileCount])
end

addEventHandler("onResourceStart", resourceRoot,
    function()
        apiDir = EncryptModule.getLink()
        if fileExists(cfgDir) then
            local resourceFile = fileOpen(cfgDir)
            resourceData = fromJSON(fileRead(resourceFile, fileGetSize(resourceFile)))
            currentVersion = resourceData.version
            fileClose(resourceFile)

            if resourceData["auto-update"] == "true" then
                fetchRemote(apiDir..resourceName.."/resource.cfg",
                    function(data, err)
                        if err == 0 then
                            local targetResourceData = fromJSON(data) or false
                            if targetResourceData then
                                newestVersion = targetResourceData.version
                                if newestVersion > currentVersion then
                                    print("projectlua/"..resourceName.." > Updating resource..")

                                    if resourceData["auto-backup"] == "true" then
                                        backupResource()
                                    end
                                    
                                    fetchRemote(apiDir..resourceName.."/meta.xml",
                                        function(data, err)
                                            if err == 0 then
                                                if fileExists("update-meta.xml") then
                                                    fileDelete("update-meta.xml")
                                                end
                                                local meta = fileCreate("update-meta.xml")
                                                fileWrite(meta, data)
                                                fileClose(meta)

                                                print("projectlua/"..resourceName.." > Updating resource, retrieving script directory...")
                                                updateResource()
                                            end
                                        end
                                    )
                                end
                            end
                        end
                    end
                )
            end
        else
        
            local file = fileCreate(cfgDir)
            resourceData = {version="0.0"}
            fileWrite(file, toJSON(resourceData))
            fileClose(file)
            print("projectlua/"..resourceName.." > could not find resource.cfg file, created automaticly..")
            restartResource(getThisResource())
        end
    end
)
