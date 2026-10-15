
-- DRONE TEST 2D - LUPI
-- Visao superior com altitude simulada

local palette = {
    0x0000, -- 0: preto
    0x03E0, -- 1: verde
    0x0200, -- 2: verde escuro
    0x7FFF, -- 3: branco
    0x7C00, -- 4: vermelho
    0x001F, -- 5: azul
    0x7FE0, -- 6: amarelo
    0x4210, -- 7: cinza
    0x03FF, -- 8: ciano
    0x7C1F  -- 9: magenta
}

local drone = {
    x = 65,
    y = 135,
    z = 0,
    vx = 0,
    vy = 0,
    bateria = 100
}

local obstaculos = {
    {x=145, y=65, w=38, h=65},
    {x=235, y=150, w=45, h=55},
    {x=325, y=45, w=35, h=70},
    {x=370, y=185, w=40, h=35}
}

local alvo = {x=435, y=130, r=18}
local pousado = false
local colisao = false
local velocidade = 0.18

function update(frame)
    -- Registrar paleta a cada frame
    for i = 1, #palette do
        ui.palset(i - 1, palette[i])
    end

    ui.cls(1)

    -- Grade do campo de testes
    for x = 0, 480, 20 do
        ui.line(x, 0, x, 270, 2)
    end
    for y = 0, 270, 20 do
        ui.line(0, y, 480, y, 2)
    end

    -- Plataforma de pouso
    ui.circ(alvo.x, alvo.y, alvo.r, 6)
    ui.circ(alvo.x, alvo.y, 10, 6)
    ui.line(alvo.x - 7, alvo.y, alvo.x + 7, alvo.y, 6)
    ui.line(alvo.x, alvo.y - 7, alvo.x, alvo.y + 7, 6)

    -- Obstaculos
    for i = 1, #obstaculos do
        local o = obstaculos[i]
        ui.rectfill(o.x, o.y, o.x + o.w, o.y + o.h, 7)
        ui.rect(o.x, o.y, o.x + o.w, o.y + o.h, 4)
    end

    -- Controle de voo
    if not pousado and not colisao then
        if ui.btn(LEFT) then
            drone.vx = drone.vx - velocidade
        end
        if ui.btn(RIGHT) then
            drone.vx = drone.vx + velocidade
        end
        if ui.btn(UP) then
            drone.vy = drone.vy - velocidade
        end
        if ui.btn(DOWN) then
            drone.vy = drone.vy + velocidade
        end

        -- Altitude simulada
        if ui.btn(BTN_X) then
            drone.z = ui.mid(0, drone.z + 0.5, 20)
        end
        if ui.btn(BTN_Z) then
            drone.z = ui.mid(0, drone.z - 0.5, 20)
        end

        -- Inercia e movimento
        drone.vx = drone.vx * 0.88
        drone.vy = drone.vy * 0.88

        drone.x = drone.x + drone.vx
        drone.y = drone.y + drone.vy

        drone.x = ui.mid(8, drone.x, 472)
        drone.y = ui.mid(38, drone.y, 262)

        -- Consumo de bateria
        if frame % 6 == 0 then
            drone.bateria = math.max(
                0, drone.bateria - 0.05
            )
        end

        -- Colisao: so em baixa altitude
        for i = 1, #obstaculos do
            local o = obstaculos[i]
            if drone.z < 5
            and drone.x + 5 > o.x
            and drone.x - 5 < o.x + o.w
            and drone.y + 5 > o.y
            and drone.y - 5 < o.y + o.h then
                colisao = true
            end
        end

        -- Pouso no alvo
        local dx = drone.x - alvo.x
        local dy = drone.y - alvo.y

        if dx * dx + dy * dy < alvo.r * alvo.r
        and drone.z < 1 then
            pousado = true
        end

        if drone.bateria <= 0 then
            colisao = true
        end
    end

    -- Desenho do drone
    local sombra = drone.z * 0.35
    ui.circfill(drone.x + sombra, drone.y + sombra,
                9, 2)

    -- Bracos e rotores
    ui.line(drone.x - 7, drone.y - 7,
            drone.x + 7, drone.y + 7, 3)
    ui.line(drone.x + 7, drone.y - 7,
            drone.x - 7, drone.y + 7, 3)

    ui.circfill(drone.x - 7, drone.y - 7, 3, 8)
    ui.circfill(drone.x + 7, drone.y - 7, 3, 8)
    ui.circfill(drone.x - 7, drone.y + 7, 3, 8)
    ui.circfill(drone.x + 7, drone.y + 7, 3, 8)
    ui.circfill(drone.x, drone.y, 4, 6)

    -- Painel de telemetria
    ui.rectfill(0, 0, 479, 29, 0)
    ui.print("DRONE TEST", 8, 5, 3)
    ui.print("ALT: " .. math.floor(drone.z), 125, 5, 8)
    ui.print("BAT: " .. math.floor(drone.bateria)
        .. "%", 220, 5, 6)
    ui.print("X:" .. math.floor(drone.x)
        .. " Y:" .. math.floor(drone.y), 335, 5, 3)

    ui.print("SETAS: MOVER | X: SUBIR | Z: DESCER",
        8, 17, 3)

    if colisao then
        ui.rectfill(100, 100, 380, 155, 0)
        ui.rect(100, 100, 380, 155, 4)
        ui.print("VOO INTERROMPIDO", 155, 115, 4)
        ui.print("BATERIA OU COLISAO", 150, 135, 3)
    elseif pousado then
        ui.rectfill(100, 100, 380, 155, 0)
        ui.rect(100, 100, 380, 155, 6)
        ui.print("POUSO CONCLUIDO!", 155, 115, 6)
        ui.print("TESTE FINALIZADO", 160, 135, 3)
    end
end
