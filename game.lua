
-- DRONE INDUSTRIAL
-- Resolucao: 480 x 270

Palette = {
    0x0000, -- 0 preto
    0x1084, -- 1 fundo escuro
    0x18C6, -- 2 metal
    0x294A, -- 3 metal claro
    0x7FE0, -- 4 laranja
    0x56B5, -- 5 azul
    0x7FFF, -- 6 branco
    0x03FF, -- 7 ciano
    0x2A80, -- 8 sombra
    0x7D20  -- 9 amarelo
}

drone = {
    x = 240,
    y = 125,
    bob = 0
}

function update(frame)
    -- Registrar paleta a cada quadro
    for i = 1, #Palette do
        ui.palset(i - 1, Palette[i])
    end

    -- CONTROLES
    if ui.btn(BTN_Z) then
        -- Botao principal Z: subir
        drone.y = drone.y - 2
    end

    if ui.btn(BTN_X) then
        -- Botao principal X: descer
        drone.y = drone.y + 2
    end

    -- Limites da tela
    drone.y = ui.mid(30, drone.y, 235)

    -- Animacao das helices
    drone.bob = (frame % 8 < 4) and 1 or 0

    -- FUNDO
    ui.cls(1)

    -- Silhueta da fabrica
    ui.rectfill(0, 45, 479, 269, 2)

    -- Chaminés e estruturas
    ui.rectfill(20, 20, 48, 175, 3)
    ui.rectfill(75, 55, 105, 195, 3)
    ui.rectfill(350, 30, 378, 175, 3)
    ui.rectfill(415, 65, 455, 195, 3)

    -- Janelas iluminadas
    for x = 25, 440, 45 do
        ui.rectfill(x, 85, x + 8, 94, 4)
    end

    -- Vigas superiores
    ui.rectfill(0, 12, 479, 20, 3)
    for x = 0, 479, 40 do
        ui.line(x, 20, x + 25, 45, 2)
        ui.line(x + 25, 45, x + 40, 20, 2)
    end

    -- Plataforma industrial
    ui.rectfill(0, 245, 479, 269, 2)
    ui.rectfill(0, 245, 479, 250, 4)

    -- Faixas de seguranca
    for x = 0, 479, 24 do
        ui.trisfill(x, 245, x + 12, 245,
                    x, 255, 9)
    end

    -- Caixas metalicas
    ui.rectfill(30, 210, 65, 243, 8)
    ui.rect(30, 210, 65, 243, 3)
    ui.line(30, 210, 65, 243, 3)
    ui.line(65, 210, 30, 243, 3)

    ui.rectfill(390, 200, 430, 243, 8)
    ui.rect(390, 200, 430, 243, 3)
    ui.line(390, 200, 430, 243, 3)
    ui.line(430, 200, 390, 243, 3)

    -- Bracos e helices
    ui.line(drone.x - 15, drone.y,
            drone.x + 15, drone.y, 3)

    ui.rectfill(drone.x - 24, drone.y - 3,
                drone.x - 8, drone.y + 1, 5)

    ui.rectfill(drone.x + 8, drone.y - 3,
                drone.x + 24, drone.y + 1, 5)

    -- Movimento visual das helices
    if drone.bob == 1 then
        ui.line(drone.x - 25, drone.y - 5,
                drone.x - 7, drone.y - 5, 7)
        ui.line(drone.x + 7, drone.y - 5,
                drone.x + 25, drone.y - 5, 7)
    else
        ui.line(drone.x - 20, drone.y - 7,
                drone.x - 10, drone.y - 7, 7)
        ui.line(drone.x + 10, drone.y - 7,
                drone.x + 20, drone.y - 7, 7)
    end

    -- Corpo do drone
    ui.rectfill(drone.x - 10, drone.y - 6,
                drone.x + 10, drone.y + 6, 5)

    ui.rectfill(drone.x - 5, drone.y - 3,
                drone.x + 5, drone.y + 3, 7)

    ui.circfill(drone.x, drone.y, 3, 6)

    -- Painel de informacoes
    ui.rectfill(6, 6, 175, 42, 0)
    ui.print("DRONE INDUSTRIAL", 12, 12, 6)
    ui.print("ALT: " .. drone.y, 12, 27, 7)

    -- Instrucoes
    ui.rectfill(325, 6, 474, 42, 0)
    ui.print("Z: SUBIR", 335, 12, 7)
    ui.print("X: DESCER", 335, 27, 7)
end
