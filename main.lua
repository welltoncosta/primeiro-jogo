
local palette = {
    0x0000, 0x03E0, 0x0200, 0x7FFF,
    0x7C00, 0x001F, 0x7FE0, 0x4210
}

local drone = {x = 240, y = 135}

function loop(frame)
    for i = 1, #palette do
        ui.palset(i - 1, palette[i])
    end

    -- Fundo
    ui.cls(1)

    -- Grade
    for x = 0, 480, 20 do
        ui.line(x, 0, x, 270, 2)
    end
    for y = 0, 270, 20 do
        ui.line(0, y, 480, y, 2)
    end

    -- Movimento pelas setas
    if ui.btn(LEFT) then drone.x = drone.x - 2 end
    if ui.btn(RIGHT) then drone.x = drone.x + 2 end
    if ui.btn(UP) then drone.y = drone.y - 2 end
    if ui.btn(DOWN) then drone.y = drone.y + 2 end

    -- A sobe e B desce
    if ui.btn(BTN_X) then drone.y = drone.y - 2 end
    if ui.btn(BTN_Z) then drone.y = drone.y + 2 end

    -- Limites da tela
    drone.x = ui.mid(8, drone.x, 472)
    drone.y = ui.mid(35, drone.y, 262)

    -- Desenhar drone
    ui.line(drone.x - 12, drone.y - 8,
            drone.x + 12, drone.y + 8, 3)
    ui.line(drone.x + 12, drone.y - 8,
            drone.x - 12, drone.y + 8, 3)

    ui.circfill(drone.x - 12, drone.y - 8, 4, 7)
    ui.circfill(drone.x + 12, drone.y - 8, 4, 7)
    ui.circfill(drone.x - 12, drone.y + 8, 4, 7)
    ui.circfill(drone.x + 12, drone.y + 8, 4, 7)
    ui.circfill(drone.x, drone.y, 5, 6)

    ui.print("A: SUBIR  B: DESCER", 10, 10, 3)
    ui.print("SETAS: MOVER", 10, 22, 3)
end
