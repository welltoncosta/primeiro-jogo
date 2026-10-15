
local palette = {
    0x0000, -- 0: Preto profundo
    0x0842, -- 1: Fundo azul escuro
    0x1084, -- 2: Azul aço escuro
    0x2108, -- 3: Cinza azulado
    0x318C, -- 4: Aço
    0x4210, -- 5: Cinza metálico
    0x5294, -- 6: Cinza claro
    0x7FFF, -- 7: Branco
    0x03E0, -- 8: Verde escuro
    0x0200, -- 9: Verde industrial
    0x7C00, -- 10: Vermelho de alerta
    0x5000, -- 11: Vermelho escuro
    0x7FE0, -- 12: Amarelo de segurança
    0x7DA0, -- 13: Laranja industrial
    0x5C80, -- 14: Laranja escuro
    0x001F, -- 15: Azul
    0x03FF, -- 16: Ciano luminoso
    0x56B5, -- 17: Cinza azulado claro
    0x294A, -- 18: Metal escuro
    0x6318, -- 19: Cinza médio
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
