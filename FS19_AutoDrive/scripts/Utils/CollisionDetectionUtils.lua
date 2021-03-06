function AutoDrive:checkForVehicleCollision(vehicle, excludedVehicles, dynamicSize)
    if excludedVehicles == nil then
        excludedVehicles = {}
    end
    table.insert(excludedVehicles, vehicle)
    return AutoDrive.checkForVehiclesInBox(AutoDrive.getBoundingBoxForVehicle(vehicle, dynamicSize), excludedVehicles)
end

function AutoDrive.checkForVehiclesInBox(boundingBox, excludedVehicles, minTurnRadius)
    for _, otherVehicle in pairs(g_currentMission.vehicles) do
        local isExcluded = false
        if excludedVehicles ~= nil and otherVehicle ~= nil then
            for _, excludedVehicle in pairs(excludedVehicles) do
                if excludedVehicle == otherVehicle or AutoDrive:checkIsConnected(excludedVehicle, otherVehicle) then
                    isExcluded = true
                end
            end
        end

        if (not isExcluded) and otherVehicle ~= nil and otherVehicle.components ~= nil and otherVehicle.sizeWidth ~= nil and otherVehicle.sizeLength ~= nil and otherVehicle.rootNode ~= nil then
            local x, _, z = getWorldTranslation(otherVehicle.components[1].node)
            local distance = MathUtil.vector2Length(boundingBox[1].x - x, boundingBox[1].z - z)
            if distance < 50 then
                if AutoDrive.boxesIntersect(boundingBox, AutoDrive.getBoundingBoxForVehicle(otherVehicle, false)) == true then
                    --[[
                    ADDrawingManager:addLineTask(boundingBox[1].x, boundingBox[1].y, boundingBox[1].z, boundingBox[2].x, boundingBox[2].y, boundingBox[2].z, 1, 0, 0)
                    ADDrawingManager:addLineTask(boundingBox[2].x, boundingBox[2].y, boundingBox[2].z, boundingBox[3].x, boundingBox[3].y, boundingBox[3].z, 1, 0, 0)
                    ADDrawingManager:addLineTask(boundingBox[3].x, boundingBox[3].y, boundingBox[3].z, boundingBox[1].x, boundingBox[1].y, boundingBox[1].z, 1, 0, 0)

                    ADDrawingManager:addLineTask(boundingBox[2].x, boundingBox[2].y, boundingBox[2].z, boundingBox[3].x, boundingBox[3].y, boundingBox[3].z, 1, 1, 1)
                    ADDrawingManager:addLineTask(boundingBox[3].x, boundingBox[3].y, boundingBox[3].z, boundingBox[4].x, boundingBox[4].y, boundingBox[4].z, 1, 1, 1)
                    ADDrawingManager:addLineTask(boundingBox[4].x, boundingBox[4].y, boundingBox[4].z, boundingBox[2].x, boundingBox[2].y, boundingBox[2].z, 1, 1, 1)
                    --]]
                    return true, false
                end
            end
                        
            if minTurnRadius ~= nil and otherVehicle.ad ~= nil and otherVehicle.ad.drivePathModule ~= nil then
                local otherWPs, otherCurrentWp = otherVehicle.ad.drivePathModule:getWayPoints()
                local lastWp = nil
                -- check for other pathfinder steered vehicles and avoid any intersection with their routes
                if otherWPs ~= nil then
                    for index, wp in pairs(otherWPs) do
                        if lastWp ~= nil and wp.id == nil and index >= otherCurrentWp and index > 2 and index < (#otherWPs - 5) then
                            local widthOfColBox = minTurnRadius
                            local sideLength = widthOfColBox / 1.66

                            local vectorX = lastWp.x - wp.x
                            local vectorZ = lastWp.z - wp.z
                            local angleRad = math.atan2(-vectorZ, vectorX)
                            angleRad = AutoDrive.normalizeAngle(angleRad)
                            local length = math.sqrt(math.pow(vectorX, 2) + math.pow(vectorZ, 2)) + widthOfColBox

                            local leftAngle = AutoDrive.normalizeAngle(angleRad + math.rad(-90))
                            local rightAngle = AutoDrive.normalizeAngle(angleRad + math.rad(90))

                            local cornerX = wp.x - math.cos(leftAngle) * sideLength
                            local cornerZ = wp.z + math.sin(leftAngle) * sideLength

                            local corner2X = lastWp.x - math.cos(leftAngle) * sideLength
                            local corner2Z = lastWp.z + math.sin(leftAngle) * sideLength

                            local corner3X = lastWp.x - math.cos(rightAngle) * sideLength
                            local corner3Z = lastWp.z + math.sin(rightAngle) * sideLength

                            local corner4X = wp.x - math.cos(rightAngle) * sideLength
                            local corner4Z = wp.z + math.sin(rightAngle) * sideLength
                            local cellBox = AutoDrive.boundingBoxFromCorners(cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z, corner4X, corner4Z)

                            if AutoDrive.boxesIntersect(boundingBox, cellBox) == true then
                                return true, true
                            end

                            if AutoDrive.boxesIntersect(boundingBox, AutoDrive.getBoundingBoxForVehicleAtPosition(otherVehicle, {x = wp.x, y = wp.y, z = wp.z}, false)) == true then
                                return true, true
                            end
                        end
                        lastWp = wp
                    end
                end
            end
        end
    end

    return false, false
end

function AutoDrive.getBoundingBoxForVehicleAtPosition(vehicle, position, dynamicSize)
    local x, y, z = position.x, position.y, position.z
    local rx, _, rz = 0, 0, 0
    local lookAheadDistance = 0
    local width = vehicle.sizeWidth
    local length = vehicle.sizeLength
    local frontToolLength = AutoDrive.getFrontToolLength(vehicle)
    if dynamicSize then
        --Box should be a lookahead box which adjusts to vehicle steering rotation
        rx, _, rz = localDirectionToWorld(vehicle.components[1].node, math.sin(vehicle.rotatedTime), 0, math.cos(vehicle.rotatedTime))
        lookAheadDistance = math.clamp(0.13, vehicle.lastSpeedReal * 3600 / 40, 1) * 11.5
    else
        rx, _, rz = localDirectionToWorld(vehicle.components[1].node, 0, 0, 1)
    end
    local vehicleVector = {x = rx, z = rz}
    local ortho = {x = -vehicleVector.z, z = vehicleVector.x}

    local boundingBox = {}
    boundingBox[1] = {
        x = x + (width / 2) * ortho.x + (length / 2 + frontToolLength) * vehicleVector.x,
        y = y + 2,
        z = z + (width / 2) * ortho.z + (length / 2 + frontToolLength) * vehicleVector.z
    }
    boundingBox[2] = {
        x = x - (width / 2) * ortho.x + (length / 2 + frontToolLength) * vehicleVector.x,
        y = y + 2,
        z = z - (width / 2) * ortho.z + (length / 2 + frontToolLength) * vehicleVector.z
    }
    boundingBox[3] = {
        x = x - (width / 2) * ortho.x + (length / 2 + frontToolLength + lookAheadDistance) * vehicleVector.x,
        y = y + 2,
        z = z - (width / 2) * ortho.z + (length / 2 + frontToolLength + lookAheadDistance) * vehicleVector.z
    }
    boundingBox[4] = {
        x = x + (width / 2) * ortho.x + (length / 2 + frontToolLength + lookAheadDistance) * vehicleVector.x,
        y = y + 2,
        z = z + (width / 2) * ortho.z + (length / 2 + frontToolLength + lookAheadDistance) * vehicleVector.z
    }

    --Box should just be vehicle dimensions;
    if not dynamicSize then
        boundingBox[1] = {
            x = x + (width / 2) * ortho.x - (length / 2) * vehicleVector.x,
            y = y + 2,
            z = z + (width / 2) * ortho.z - (length / 2) * vehicleVector.z
        }
        boundingBox[2] = {
            x = x - (width / 2) * ortho.x - (length / 2) * vehicleVector.x,
            y = y + 2,
            z = z - (width / 2) * ortho.z - (length / 2) * vehicleVector.z
        }
    end

    --ADDrawingManager:addLineTask(boundingBox[1].x, boundingBox[1].y, boundingBox[1].z, boundingBox[2].x, boundingBox[2].y, boundingBox[2].z, 1, 1, 0)
    --ADDrawingManager:addLineTask(boundingBox[2].x, boundingBox[2].y, boundingBox[2].z, boundingBox[3].x, boundingBox[3].y, boundingBox[3].z, 1, 1, 0)
    --ADDrawingManager:addLineTask(boundingBox[3].x, boundingBox[3].y, boundingBox[3].z, boundingBox[4].x, boundingBox[4].y, boundingBox[4].z, 1, 1, 0)
    --ADDrawingManager:addLineTask(boundingBox[4].x, boundingBox[4].y, boundingBox[4].z, boundingBox[1].x, boundingBox[1].y, boundingBox[1].z, 1, 1, 0)

    return boundingBox
end

function AutoDrive.getBoundingBoxForVehicle(vehicle, dynamicSize)
    local x, y, z = getWorldTranslation(vehicle.components[1].node)

    local position = {x = x, y = y, z = z}

    return AutoDrive.getBoundingBoxForVehicleAtPosition(vehicle, position, dynamicSize)
end

function AutoDrive.getDistanceBetween(vehicleOne, vehicleTwo)
    local x1, _, z1 = getWorldTranslation(vehicleOne.components[1].node)
    local x2, _, z2 = getWorldTranslation(vehicleTwo.components[1].node)

    return math.sqrt(math.pow(x2 - x1, 2) + math.pow(z2 - z1, 2))
end

function AutoDrive.getFrontToolLength(vehicle)
    local lengthOfFrontTool = 0

    if vehicle.getAttachedImplements ~= nil then
        for _, impl in pairs(vehicle:getAttachedImplements()) do
            local tool = impl.object
            if tool ~= nil and tool.sizeLength ~= nil then
                --Check if tool is in front of vehicle
                local toolX, toolY, toolZ = getWorldTranslation(tool.components[1].node)
                local _, _, offsetZ =  worldToLocal(vehicle.components[1].node, toolX, toolY, toolZ)
                if offsetZ > 0 then
                    lengthOfFrontTool = math.max(lengthOfFrontTool, tool.sizeLength)
                end
            end
        end
    end

    return lengthOfFrontTool
end