-- ============================================================
--  SISTEMA CRITICO  —  jogo para o Lupi (arquivo: drones.lua)
--  Game Jam do Lupi · Latinoware 2026
--  Tema: FALHA NO SISTEMA
--
--  Você pilota um DRONE PRETO e precisa chegar até a COMPORTA de cada
--  setor. Os 4 drones de defesa ficam em REPOUSO... até que, num
--  momento ALEATÓRIO, acontece a FALHA CRÍTICA: abre-se uma janela com
--  um CÓDIGO DE REPARO (conta matemática).
--    * Acertou? O sistema é reparado e você segue até a comporta.
--    * Errou (ou o tempo acabou)? A comporta trava e os drones acordam
--      e perseguem você até o sistema REINICIAR (8s) e a comporta abrir.
--
--  O enxame usa 4 PAPÉIS de perseguição (perseguidor, interceptador,
--  flanqueador e errante). Cada drone tem velocidade própria, sempre
--  menor que a do jogador. Dos genes do GENOMA (treinar_drones.py)
--  continuam em uso: separation e predict.
--
--  Controles: D-pad (8 direções) move o drone preto e navega nos
--             menus; B (= BTN_Z) confirma; X (= BTN_X) volta.
-- ============================================================

-- ===== PALETA (RGB555) =====
Palette = {
  0x0000, --  0 preto
  0x0016, --  1 azul-marinho (fundo)
  0x7FFF, --  2 branco
  0x7C00, --  3 vermelho
  0x03E0, --  4 verde
  0x7FE0, --  5 amarelo
  0x001F, --  6 azul
  0x03FF, --  7 ciano
  0x7C1F, --  8 magenta
  0x39E7, --  9 cinza
  0x7BE0, -- 10 laranja
  0x4BE0, -- 11 verde-claro
  0x18C6, -- 12 cinza-escuro
  0x7C40, -- 13 vermelho-claro
  0x3186, -- 14 azul-escuro (drones brancos? não: fundo aux)
  0x5294, -- 15 cinza-médio
}

-- ===== GENOMA (treinado pelo GA — treinar_drones.py) =====
-- Em uso no enxame: separation e predict.
-- (cohesion, alignment, seek e max_speed não são mais usados)
GENOMA = {
  cohesion = 1.1003,
  separation = 0.4466,
  alignment = 0.5774,
  seek = 0.2715,
  predict = 24.2772,
  max_speed = 3.7317,
}

-- ===== CONSTANTES =====
-- estados
local MENU, NOME, NIVEL, CONTA, JOGO, TRANSICAO, RESULTADO, RANKING = 0,1,2,3,4,5,6,7

-- modos dentro da fase (estado JOGO)
local M_NORMAL, M_PERSEGUICAO, M_REPARADO = 0, 1, 2

-- transição entre setores (frames)
local TRANS_FECHA = 35    -- portas fecham sobre o setor concluído
local TRANS_TEXTO = 80    -- portas fechadas: resumo + carregando próximo setor
local TRANS_ABRE  = 35    -- portas abrem revelando o novo setor

-- cor de fundo de cada setor (RGB555): azul, roxo, verde-azulado, vinho, vermelho escuro
local FUNDOS = { 0x0016, 0x200E, 0x014C, 0x3044, 0x2804 }

-- cores
local C_PRETO, C_FUNDO, C_BRANCO = 0,1,2
local C_VERMELHO, C_VERDE, C_AMARELO = 3,4,5
local C_AZUL, C_CIANO, C_MAGENTA, C_CINZA = 6,7,8,9
local C_LARANJA, C_VERDE_CLARO, C_CINZA_ESCURO = 10,11,12

-- jogo
local LARGURA, ALTURA = 480, 270
local PLAYER_SPEED = 3.6
local CATCH_DIST = 8
local N_DRONES = 4        -- um de cada papel
local HACK_FRAMES = 480   -- 8 segundos a 60 FPS
local TOTAL_FASES = 5
local TEMPO_CONTA = 600   -- 10 segundos

-- posição inicial dos drones
local DIST_MIN_PLAYER = 90  -- distância mínima do jogador
local DIST_MIN_DRONES = 40  -- distância mínima entre drones
local DIST_MIN_PORTA  = 60  -- distância mínima da porta
local DIST_MIN_PORTA_PLAYER = 220  -- a porta nasce longe do jogador

-- falha crítica (momento aleatório)
local FALHA_MIN    = 45    -- frames mínimos até a falha (0,75 s)
local FALHA_MAX    = 240   -- frames máximos até a falha (4 s)
local RAIO_GATILHO = 70    -- se o jogador chegar tão perto da porta, a falha dispara na hora

-- enxame
local VEL_BASE       = { 0.50, 0.60, 0.70 } -- fração da velocidade do jogador, por nível
local VEL_POR_FASE   = 0.02                 -- aumento por fase
local ACEL           = 0.12                 -- curva máxima por frame (menor = mais fácil de driblar)
local RAIO_ALERTA    = 130                  -- o "errante" só persegue dentro desse raio
local RAIO_SEP       = 40                   -- distância de separação entre drones
local ESPERA_ACORDAR = 20                   -- frames até o 1º drone acordar (os outros vêm depois)

-- ===== ESTADO GLOBAL =====
local estado = MENU
local frame_cont = 0

-- menu
local menu_sel = 0

-- nome
local nome = ""
local NOME_CELLS = {}
local nome_cursor = 0
local nome_cols = 10

-- monta as células do teclado: A-Z, 0-9, espaço, backspace, OK
do
  local i
  for i = 0, 25 do NOME_CELLS[#NOME_CELLS + 1] = { tipo = "char", rotulo = string.char(65 + i) } end
  for i = 0, 9 do NOME_CELLS[#NOME_CELLS + 1] = { tipo = "char", rotulo = tostring(i) } end
  NOME_CELLS[#NOME_CELLS + 1] = { tipo = "char", rotulo = " " }
  NOME_CELLS[#NOME_CELLS + 1] = { tipo = "back", rotulo = "<" }
  NOME_CELLS[#NOME_CELLS + 1] = { tipo = "ok", rotulo = "OK" }
end

-- nível
local nivel_sel = 0   -- 0=facil, 1=inter, 2=dificil
local NIVEL_NOMES = { "FACIL", "INTERMEDIARIO", "DIFICIL" }

-- pontuação / progresso
local pontos = 0
local fase = 1
local acertou_todas = true      -- nunca apareceram drones
local nunca_morreu = true       -- nunca foi pego

-- conta (pergunta)
local conta_texto, conta_resp, conta_opcoes, conta_sel, conta_timer

-- fuga
local player, drones, porta, fuga_timer, porta_aberta
local modo = M_NORMAL
local falha_timer = 0

-- transição
local trans_t, trans_final = 0, false

-- resultado
local entrou_ranking = false

-- ranking (top 10)
local ranking = {}

-- efeitos
local shake = 0
local popup_txt, popup_cor, popup_timer = nil, 0, 0

-- ===== HELPERS =====
local function rnd(a, b)
  return math.random(a, b)
end

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function texto_central(t, y, cor)
  local w = #t * 6
  ui.print(t, math.floor((LARGURA - w) / 2), y, cor)
end

local function popup(txt, cor)
  popup_txt, popup_cor, popup_timer = txt, cor, 45
end

local function som(n)
  sfx.fx(0, n, 0.5)
end
local function som_acerto() som(72) end
local function som_erro() som(40) end
local function som_clique() som(60) end
local function som_vitoria() som(84) end

local function ir_para(s)
  estado = s
end

-- ===== RANKING (persistência via io) =====
local function carregar_ranking()
  ranking = {}
  local f = io.open("ranking.txt", "r")
  if not f then return end
  for linha in f:lines() do
    local nome_v, pts = linha:match("^(.*)|(%d+)$")
    if nome_v then
      ranking[#ranking + 1] = { nome = nome_v, pontos = tonumber(pts) }
    end
  end
  f:close()
end

local function salvar_ranking()
  local f = io.open("ranking.txt", "w")
  if not f then return end
  for _, e in ipairs(ranking) do
    f:write(e.nome .. "|" .. e.pontos .. "\n")
  end
  f:close()
end

local function inserir_ranking(nome_v, pts)
  table.insert(ranking, { nome = nome_v, pontos = pts })
  table.sort(ranking, function(a, b) return a.pontos > b.pontos end)
  if #ranking > 10 then
    ranking[#ranking] = nil
  end
end

-- ===== MATEMÁTICA =====
local function tem(tab, v)
  for _, x in ipairs(tab) do
    if x == v then return true end
  end
  return false
end

local function gerar_opcoes(resp)
  local op = { resp }
  while #op < 3 do
    local d = rnd(1, 8) * (rnd(0, 1) == 0 and 1 or -1)
    local candidato = resp + d
    if candidato >= 0 and not tem(op, candidato) then
      op[#op + 1] = candidato
    end
  end
  -- embaralha
  for i = 3, 2, -1 do
    local j = rnd(1, i)
    op[i], op[j] = op[j], op[i]
  end
  return op
end

local function gerar_conta(nivel, fase_atual)
  -- nivel: 0=facil, 1=intermediario, 2=dificil
  if nivel == 0 then
    if fase_atual <= 2 then
      local a, b = rnd(2, 10 + fase_atual * 4), rnd(2, 10 + fase_atual * 4)
      return a .. " + " .. b .. " = ?", a + b
    elseif fase_atual <= 4 then
      local a, b = rnd(5, 10 + fase_atual), rnd(2, 9)
      return a .. " x " .. b .. " = ?", a * b
    else
      local a = rnd(15, 50)
      local b = rnd(2, a - 1)
      return a .. " - " .. b .. " = ?", a - b
    end
  elseif nivel == 1 then
    if fase_atual <= 2 then
      local a, b = rnd(6, 15), rnd(6, 15)
      return a .. " x " .. b .. " = ?", a * b
    elseif fase_atual == 3 then
      local b, c = rnd(2, 12), rnd(2, 12)
      return (b * c) .. " / " .. b .. " = ?", c
    else
      local a, b, c = rnd(2, 12), rnd(2, 12), rnd(2, 12)
      return a .. " x " .. b .. " + " .. c .. " = ?", a * b + c
    end
  else
    if fase_atual <= 2 then
      local a, b, c = rnd(2, 9), rnd(2, 9), rnd(2, 5)
      return "(" .. a .. " + " .. b .. ") x " .. c .. " = ?", (a + b) * c
    elseif fase_atual == 3 then
      local a, b = rnd(2, 5), rnd(2, 3)
      return a .. "^" .. b .. " = ?", math.floor(a ^ b + 0.5)
    elseif fase_atual == 4 then
      local quadrados = { 4, 9, 16, 25, 36, 49, 64, 81, 100, 121, 144 }
      local x = quadrados[rnd(1, #quadrados)]
      return "sqrt(" .. x .. ") = ?", math.floor(math.sqrt(x) + 0.5)
    else
      local fracs = { {1,2,1,2}, {1,4,3,4}, {1,3,2,3}, {2,5,3,5}, {3,8,5,8} }
      local f = fracs[rnd(1, #fracs)]
      return f[1] .. "/" .. f[2] .. " + " .. f[3] .. "/" .. f[4] .. " = ?", 1
    end
  end
end

-- ===== INÍCIO DE FASE (conta) =====
local function iniciar_conta()
  conta_texto, conta_resp = gerar_conta(nivel_sel, fase)
  conta_opcoes = gerar_opcoes(conta_resp)
  conta_sel = 0
  conta_timer = TEMPO_CONTA
  ir_para(CONTA)
end

-- ===== INÍCIO DE FASE =====

-- true se (x, y) está a pelo menos dmin de todos os itens da lista
local function longe_de(x, y, lista, dmin)
  for _, o in ipairs(lista) do
    local dx, dy = x - o.x, y - o.y
    if dx * dx + dy * dy < dmin * dmin then return false end
  end
  return true
end

local function iniciar_fase()
  player = { x = rnd(60, LARGURA - 60), y = rnd(60, ALTURA - 60), vx = 0, vy = 0 }

  -- porta numa borda, longe do jogador
  for _ = 1, 30 do
    local edge = rnd(0, 3)
    if edge == 0 then porta = { x = rnd(30, LARGURA - 30), y = 14 }
    elseif edge == 1 then porta = { x = rnd(30, LARGURA - 30), y = ALTURA - 14 }
    elseif edge == 2 then porta = { x = 14, y = rnd(30, ALTURA - 30) }
    else porta = { x = LARGURA - 14, y = rnd(30, ALTURA - 30) } end
    if longe_de(porta.x, porta.y, { player }, DIST_MIN_PORTA_PLAYER) then break end
  end

  -- drones espalhados (começam em repouso)
  drones = {}
  for _ = 1, N_DRONES do
    local x, y
    for _ = 1, 30 do  -- até 30 tentativas por drone
      x = rnd(8, LARGURA - 8)
      y = rnd(8, ALTURA - 8)
      if longe_de(x, y, { player }, DIST_MIN_PLAYER)
         and longe_de(x, y, { porta }, DIST_MIN_PORTA)
         and longe_de(x, y, drones, DIST_MIN_DRONES) then
        break
      end
    end

    local n = #drones
    local f = VEL_BASE[nivel_sel + 1] + (fase - 1) * VEL_POR_FASE
    drones[#drones + 1] = {
      x = x, y = y, vx = 0, vy = 0,
      papel = (n % 4) + 1,                                  -- 1 a 4: um de cada
      vmax = PLAYER_SPEED * f * (0.9 + rnd(0, 20) / 100),   -- ±10% por drone
      espera = 0,
      t = rnd(0, 149),
      ang = rnd(0, 628) / 100,
      wx = rnd(8, LARGURA - 8), wy = rnd(8, ALTURA - 8),
    }
  end

  modo = M_NORMAL
  falha_timer = rnd(FALHA_MIN, FALHA_MAX)   -- momento aleatório da falha
  porta_aberta = true
  fuga_timer = HACK_FRAMES
  ir_para(JOGO)
end

-- ===== ENXAME (papéis diferentes + velocidade própria) =====

-- cada papel escolhe um alvo diferente
local function alvo_do_drone(d)
  local px, py = player.x, player.y
  local tx, ty

  if d.papel == 1 then
    -- perseguidor: vai direto no jogador
    tx, ty = px, py

  elseif d.papel == 2 then
    -- interceptador: mira à frente de onde o jogador está indo
    tx = px + player.vx * GENOMA.predict
    ty = py + player.vy * GENOMA.predict

  elseif d.papel == 3 then
    -- flanqueador: circula o jogador e depois mergulha
    if (d.t % 150) < 90 then
      local a = d.t * 0.03 + d.ang
      tx, ty = px + math.cos(a) * 70, py + math.sin(a) * 70
    else
      tx, ty = px, py
    end

  else
    -- errante: patrulha e só persegue se o jogador chegar perto
    local dx, dy = px - d.x, py - d.y
    if dx * dx + dy * dy < RAIO_ALERTA * RAIO_ALERTA then
      tx, ty = px, py
    else
      local wx, wy = d.wx - d.x, d.wy - d.y
      if d.t % 120 == 0 or wx * wx + wy * wy < 100 then
        d.wx, d.wy = rnd(8, LARGURA - 8), rnd(8, ALTURA - 8)
      end
      tx, ty = d.wx, d.wy
    end
  end

  return clamp(tx, 8, LARGURA - 8), clamp(ty, 8, ALTURA - 8)
end

local function atualizar_enxame()
  local perseguindo = (modo == M_PERSEGUICAO)
  for i, d in ipairs(drones) do
    d.t = d.t + 1

    if not perseguindo then
      -- repouso: freia suavemente e fica parado
      d.vx = d.vx * 0.85
      d.vy = d.vy * 0.85
      d.x = clamp(d.x + d.vx, 8, LARGURA - 8)
      d.y = clamp(d.y + d.vy, 8, ALTURA - 8)
    elseif d.espera > 0 then
      d.espera = d.espera - 1   -- ainda acordando
    else
      -- velocidade desejada (em direção ao alvo do papel)
      local tx, ty = alvo_do_drone(d)
      local dx, dy = tx - d.x, ty - d.y
      local dist = math.sqrt(dx * dx + dy * dy) + 0.01
      local desx = dx / dist * d.vmax
      local desy = dy / dist * d.vmax

      -- separação: afasta de vizinhos próximos (usa o gene do GA)
      for j, o in ipairs(drones) do
        if i ~= j then
          local ox, oy = d.x - o.x, d.y - o.y
          local d2 = ox * ox + oy * oy
          if d2 < RAIO_SEP * RAIO_SEP and d2 > 0 then
            local dd = math.sqrt(d2)
            local peso = (1 - dd / RAIO_SEP) * GENOMA.separation * d.vmax * 2
            desx = desx + ox / dd * peso
            desy = desy + oy / dd * peso
          end
        end
      end

      -- direção limitada: não vira de repente
      local sx, sy = desx - d.vx, desy - d.vy
      local sl = math.sqrt(sx * sx + sy * sy)
      if sl > ACEL then
        sx = sx / sl * ACEL
        sy = sy / sl * ACEL
      end
      d.vx = d.vx + sx
      d.vy = d.vy + sy

      -- teto de velocidade individual
      local sp = math.sqrt(d.vx * d.vx + d.vy * d.vy)
      if sp > d.vmax then
        d.vx = d.vx / sp * d.vmax
        d.vy = d.vy / sp * d.vmax
      end

      d.x = clamp(d.x + d.vx, 8, LARGURA - 8)
      d.y = clamp(d.y + d.vy, 8, ALTURA - 8)
    end
  end
end

-- ===== MOVIMENTO DO JOGADOR (8 direções) =====
local function atualizar_player()
  local dx, dy = 0, 0
  if ui.btn(LEFT) then dx = dx - 1 end
  if ui.btn(RIGHT) then dx = dx + 1 end
  if ui.btn(UP) then dy = dy - 1 end
  if ui.btn(DOWN) then dy = dy + 1 end
  -- diagonal: normaliza
  if dx ~= 0 and dy ~= 0 then
    dx = dx * 0.7071
    dy = dy * 0.7071
  end
  player.vx = dx * PLAYER_SPEED
  player.vy = dy * PLAYER_SPEED
  player.x = clamp(player.x + player.vx, 8, LARGURA - 8)
  player.y = clamp(player.y + player.vy, 8, ALTURA - 8)
end

-- ===== DESENHO DE UM DRONE =====
local function desenhar_drone(x, y, cor_corpo, cor_detalhe)
    -- Dimensões do corpo e braços
    local t = 6          -- Metade do tamanho do quadrado central (corpo 12x12)
    local arm = 11       -- Distância dos motores a partir do centro

    -- 1. Braços do drone (linhas duplas horizontais/verticais para dar grossura)
    ui.line(x - arm, y - 2, x + arm, y - 2, C_CINZA)
    ui.line(x - arm, y + 2, x + arm, y + 2, C_CINZA)
    ui.line(x - 2, y - arm, x - 2, y + arm, C_CINZA)
    ui.line(x + 2, y - arm, x + 2, y + arm, C_CINZA)

    -- 2. Corpo Central (Base Quadrada + Borda)
    ui.rectfill(x - t, y - t, x + t, y + t, cor_corpo)
    ui.rect(x - t, y - t, x + t, y + t, C_PRETO)

    -- 3. Detalhes do Painel Interno (Núcleo/Bateria)
    ui.rectfill(x - 3, y - 3, x + 3, y + 3, cor_detalhe)
    ui.rect(x - 3, y - 3, x + 3, y + 3, C_BRANCO)

    -- 4. Sensores/Câmeras na frente (orientação para cima - Y negativo)
    ui.rectfill(x - 2, y - t - 2, x + 2, y - t, C_PRETO)
    ui.circfill(x, y - t - 1, 1, C_VERMELHO) -- Lente da câmera

    -- 5. Motores (Bases circulares nas 4 pontas)
    ui.circfill(x - arm, y - arm, 3, C_CINZA)
    ui.circfill(x + arm, y - arm, 3, C_CINZA)
    ui.circfill(x - arm, y + arm, 3, C_CINZA)
    ui.circfill(x + arm, y + arm, 3, C_CINZA)

    -- 7. Hélices (Anéis/Círculos vazados)
    ui.circ(x - arm, y - arm, 5, C_BRANCO)
    ui.circ(x + arm, y - arm, 5, C_BRANCO)
    ui.circ(x - arm, y + arm, 5, C_BRANCO)
    ui.circ(x + arm, y + arm, 5, C_BRANCO)
end

-- ===== DRONE INIMIGO (sentinela em losango) =====
-- Pequeno, colorido por papel. Em repouso: cinza, olho fechado, flutuando.
-- Acordado: borda branca e olho que segue o jogador.
local COR_PAPEL = { C_VERMELHO, C_LARANJA, C_MAGENTA, C_VERDE_CLARO }

local function desenhar_inimigo(d)
  local acordado = (modo == M_PERSEGUICAO and d.espera <= 0)
  local x = d.x
  local y = d.y
  if not acordado then
    y = y + math.floor(math.sin(frame_cont / 30 + d.ang) * 2 + 0.5)  -- flutua
  end
  local r = 5
  local cor = COR_PAPEL[d.papel]
  local borda = acordado and C_BRANCO or C_CINZA

  -- antenas curtas
  ui.line(x - r - 3, y, x - r, y, C_CINZA)
  ui.line(x + r, y, x + r + 3, y, C_CINZA)
  ui.line(x, y - r - 3, x, y - r, C_CINZA)
  ui.circfill(x, y - r - 3, 1, cor)

  -- corpo em losango
  ui.trisfill(x, y - r, x + r, y, x, y + r, cor)
  ui.trisfill(x, y - r, x - r, y, x, y + r, cor)
  ui.line(x, y - r, x + r, y, borda)
  ui.line(x + r, y, x, y + r, borda)
  ui.line(x, y + r, x - r, y, borda)
  ui.line(x - r, y, x, y - r, borda)

  if acordado then
    -- olho aberto, acompanha o jogador
    local dx, dy = player.x - x, player.y - y
    local l = math.sqrt(dx * dx + dy * dy) + 0.01
    ui.circfill(x, y, 2, C_BRANCO)
    ui.circfill(x + math.floor(dx / l + 0.5), y + math.floor(dy / l + 0.5), 1, C_PRETO)
    -- propulsor piscando
    if math.floor(frame_cont / 4) % 2 == 0 then
      ui.circfill(x, y + r + 2, 1, C_BRANCO)
    end
  else
    -- olho fechado + "z"
    ui.line(x - 2, y, x + 2, y, C_PRETO)
    if math.floor(frame_cont / 30) % 2 == 0 then
      ui.print("z", x + 7, y - 12, C_CINZA)
    end
  end
end

-- ===== PORTA, CENA, GLITCH E HUD =====
local function desenhar_porta()
  local x0, y0, x1, y1 = porta.x - 14, porta.y - 14, porta.x + 14, porta.y + 14
  if porta_aberta then
    ui.rectfill(x0, y0, x1, y1, C_VERDE)
    ui.rect(x0, y0, x1, y1, C_BRANCO)
    local pulso = math.floor(math.sin(frame_cont / 10) * 2 + 0.5)
    ui.circ(porta.x, porta.y, 20 + pulso, C_VERDE)   -- anel pulsante
  else
    ui.rectfill(x0, y0, x1, y1, C_CINZA)
    ui.rect(x0, y0, x1, y1, C_VERMELHO)
  end
end

local function desenhar_cena()
  desenhar_porta()
  for _, d in ipairs(drones) do
    desenhar_inimigo(d)
  end
  -- jogador (drone preto)
  desenhar_drone(player.x, player.y, C_PRETO, 7)
  ui.circ(player.x, player.y, 7, C_AMARELO)
end

-- grade de fundo: cada setor tem um espaçamento diferente
local function desenhar_fundo()
  local e = 60 - fase * 8   -- 52, 44, 36, 28, 20
  for x = 0, LARGURA, e do
    ui.line(x, 0, x, ALTURA, C_CINZA_ESCURO)
  end
  for y = 0, ALTURA, e do
    ui.line(0, y, LARGURA, y, C_CINZA_ESCURO)
  end
end

-- portas metálicas que fecham (h cresce) ou abrem (h diminui) a tela
local function desenhar_portoes(h)
  if h <= 0 then return end
  ui.rectfill(0, 0, LARGURA, h, C_CINZA_ESCURO)
  ui.rectfill(0, ALTURA - h, LARGURA, ALTURA, C_CINZA_ESCURO)
  for y = 6, h, 12 do
    ui.line(0, y, LARGURA, y, C_CINZA)
    ui.line(0, ALTURA - y, LARGURA, ALTURA - y, C_CINZA)
  end
  ui.line(0, h, LARGURA, h, C_AMARELO)
  ui.line(0, ALTURA - h, LARGURA, ALTURA - h, C_AMARELO)
end

-- efeito de glitch (sistema falhando); n = quantidade de faixas
local function desenhar_glitch(n)
  for _ = 1, n do
    local gy = rnd(0, ALTURA)
    local gh = rnd(1, 5)
    ui.rectfill(0, gy, LARGURA, gy + gh, (rnd(0, 1) == 0) and C_VERMELHO or C_CIANO)
  end
  if (frame_cont % 3) == 0 then
    for _ = 1, 3 do
      local gy = rnd(0, ALTURA)
      local gx = rnd(0, LARGURA - 70)
      ui.rectfill(gx, gy, gx + rnd(20, 70), gy + 1, C_MAGENTA)
    end
  end
end

local function desenhar_hud()
  ui.print("SETOR " .. fase .. "/" .. TOTAL_FASES, 8, 7, C_CIANO)
  local pts_txt = "PONTOS " .. pontos
  ui.print(pts_txt, LARGURA - 8 - #pts_txt * 6, 7, C_AMARELO)

  local piscar = math.floor(frame_cont / 15) % 2 == 0
  if estado == CONTA then
    if piscar then texto_central("! SISTEMA EM FALHA !", 7, C_VERMELHO) end
  elseif modo == M_PERSEGUICAO then
    local bw = 200
    local bx = math.floor((LARGURA - bw) / 2)
    local proporcao = 1 - (fuga_timer / HACK_FRAMES)
    texto_central("REINICIANDO SISTEMA...", 4, C_CIANO)
    ui.rectfill(bx, 16, bx + math.floor(bw * proporcao), 24, C_CIANO)
    ui.rect(bx, 16, bx + bw, 24, C_CINZA)
    if piscar then texto_central("! DEFESAS INSTAVEIS - ERR 0x07F", 30, C_VERMELHO) end
  elseif modo == M_REPARADO then
    texto_central("SISTEMA ESTAVEL", 7, C_VERDE)
  else
    texto_central("SISTEMA ONLINE", 7, C_VERDE)
  end
end

-- ===== EVENTOS DA FALHA =====

-- a falha acontece: trava a porta e abre a janela da conta
local function disparar_falha()
  porta_aberta = false
  shake = 6
  som_erro()
  iniciar_conta()
end

-- acertou: sistema reparado, drones continuam em repouso
local function acertar_equacao()
  local bonus = math.floor(conta_timer / TEMPO_CONTA * 100)
  local pts = 100 + bonus
  pontos = pontos + pts
  popup("SISTEMA REPARADO! +" .. pts, C_VERDE)
  som_acerto()
  modo = M_REPARADO
  porta_aberta = true
  ir_para(JOGO)
end

-- errou ou tempo esgotado: drones acordam e perseguem até a porta abrir
local function errar_equacao()
  acertou_todas = false
  modo = M_PERSEGUICAO
  porta_aberta = false
  fuga_timer = HACK_FRAMES
  -- acordam um de cada vez; os que estão perto do jogador demoram um pouco mais
  for i, d in ipairs(drones) do
    local dx, dy = d.x - player.x, d.y - player.y
    local perto = (dx * dx + dy * dy < 80 * 80) and 45 or 0
    d.espera = ESPERA_ACORDAR + (i - 1) * 15 + perto
  end
  ir_para(JOGO)
end

-- ===== TELAS =====

local function update_menu()
  ui.cls(C_FUNDO)
  texto_central("SISTEMA CRITICO", 40, C_BRANCO)
  local itens = { "NOVO JOGO", "RANKING" }
  if ui.btnp(DOWN) then menu_sel = (menu_sel + 1) % 2; som_clique() end
  if ui.btnp(UP) then menu_sel = (menu_sel - 1) % 2; som_clique() end
  for i = 1, 2 do
    local y = 100 + i * 45
    local cor = (i - 1 == menu_sel) and C_AMARELO or C_CINZA
    if i - 1 == menu_sel then ui.rectfill(170, y - 14, 310, y + 14, C_CINZA_ESCURO) end
    texto_central(itens[i], y - 3, cor)
  end
  if ui.btnp(BTN_Z) then
    som_clique()
    -- semear o random (antes feito na tela de título)
    local t = (os and os.time) and os.time() or 0
    math.randomseed(frame_cont * 7919 + 1 + t)
    if menu_sel == 0 then
      nome = ""
      nome_cursor = 0
      ir_para(NOME)
    else
      carregar_ranking()
      ir_para(RANKING)
    end
  end
end

-- ---- NOME ----
local function update_nome()
  ui.cls(C_FUNDO)
  texto_central("DIGITE SEU NOME", 30, C_BRANCO)
  texto_central(nome .. (frame_cont % 40 < 20 and "_" or ""), 52, C_AMARELO)
  texto_central("(max 8 letras)", 66, C_CINZA)

  local colunas = nome_cols
  local gw, gh = 34, 22
  local gx0 = math.floor((LARGURA - colunas * gw) / 2)
  local gy0 = 88
  for i = 1, #NOME_CELLS do
    local cx = (i - 1) % colunas
    local cy = math.floor((i - 1) / colunas)
    local gx = gx0 + cx * gw
    local gy = gy0 + cy * gh
    local sel = (i - 1 == nome_cursor)
    if sel then ui.rectfill(gx, gy, gx + gw - 2, gy + gh - 2, C_AMARELO) end
    ui.print(NOME_CELLS[i].rotulo, gx + 12, gy + 4, sel and C_PRETO or C_BRANCO)
  end

  if ui.btnp(LEFT) then nome_cursor = (nome_cursor - 1 + #NOME_CELLS) % #NOME_CELLS; som_clique() end
  if ui.btnp(RIGHT) then nome_cursor = (nome_cursor + 1) % #NOME_CELLS; som_clique() end
  if ui.btnp(UP) then nome_cursor = (nome_cursor - colunas + #NOME_CELLS) % #NOME_CELLS; som_clique() end
  if ui.btnp(DOWN) then nome_cursor = (nome_cursor + colunas) % #NOME_CELLS; som_clique() end

  if ui.btnp(BTN_Z) then
    local cel = NOME_CELLS[nome_cursor + 1]
    if cel.tipo == "char" then
      if #nome < 8 then nome = nome .. cel.rotulo; som_clique() end
    elseif cel.tipo == "back" then
      nome = string.sub(nome, 1, #nome - 1); som_clique()
    elseif cel.tipo == "ok" then
      if #nome == 0 then nome = "JOGADOR" end
      som_clique()
      nivel_sel = 0
      ir_para(NIVEL)
    end
  end

  if ui.btnp(BTN_X) then
    if #nome == 0 then nome = "JOGADOR" end
    som_clique()
    nivel_sel = 0
    ir_para(NIVEL)
  end
end

-- ---- NÍVEL ----
local function update_nivel()
  ui.cls(C_FUNDO)
  texto_central("ESCOLHA O NIVEL", 40, C_BRANCO)
  for i = 0, 2 do
    local y = 100 + i * 40
    local cor = (i == nivel_sel) and C_AMARELO or C_CINZA
    if i == nivel_sel then ui.rectfill(180, y - 14, 300, y + 14, C_CINZA_ESCURO) end
    texto_central(NIVEL_NOMES[i + 1], y - 3, cor)
  end
  if ui.btnp(DOWN) then nivel_sel = (nivel_sel + 1) % 3; som_clique() end
  if ui.btnp(UP) then nivel_sel = (nivel_sel - 1) % 3; som_clique() end
  if ui.btnp(BTN_Z) then
    som_clique()
    fase = 1
    pontos = 0
    acertou_todas = true
    nunca_morreu = true
    entrou_ranking = false
    iniciar_fase()
  end
  if ui.btnp(BTN_X) then som_clique(); ir_para(MENU) end
end

-- ---- AVANÇAR FASE (forward declaration) ----
local avancar_fase

-- ---- CONTA (janela de reparo sobre a cena congelada) ----
local function update_conta()
  ui.cls(C_FUNDO)
  desenhar_fundo()
  desenhar_cena()

  -- escurece a cena (linhas de varredura) e mostra o glitch
  for y = 0, ALTURA, 2 do
    ui.line(0, y, LARGURA, y, C_PRETO)
  end
  desenhar_glitch(2)
  desenhar_hud()

  -- janela
  local wx0, wy0, wx1, wy1 = 50, 34, 430, 210
  ui.rectfill(wx0, wy0, wx1, wy1, C_FUNDO)
  ui.rect(wx0, wy0, wx1, wy1, C_BRANCO)
  ui.rectfill(wx0 + 1, wy0 + 1, wx1 - 1, wy0 + 18, C_VERMELHO)
  local piscar = math.floor(frame_cont / 15) % 2 == 0
  texto_central("!! FALHA CRITICA !!", wy0 + 6, piscar and C_BRANCO or C_AMARELO)
  texto_central("REPARE O SISTEMA - INSIRA O CODIGO", wy0 + 30, C_BRANCO)

  -- timer (barra)
  local bw = 300
  local bx = math.floor((LARGURA - bw) / 2)
  local proporcao = ui.mid(0, conta_timer / TEMPO_CONTA, 1)
  ui.rectfill(bx, 78, bx + math.floor(bw * proporcao), 86, C_LARANJA)
  ui.rect(bx, 78, bx + bw, 86, C_CINZA)

  -- pergunta
  texto_central(conta_texto, 104, C_BRANCO)

  -- opções
  for i = 0, 2 do
    local x = 140 + i * 100
    local cor = (i == conta_sel) and C_AMARELO or C_CINZA
    if i == conta_sel then ui.rectfill(x - 40, 126, x + 40, 154, C_CINZA_ESCURO) end
    local t = tostring(conta_opcoes[i + 1])
    ui.print(t, x - math.floor(#t * 3), 136, cor)
  end
  texto_central("< > escolher    B confirmar", 186, C_CINZA)

  if ui.btnp(LEFT) then conta_sel = (conta_sel - 1) % 3; som_clique() end
  if ui.btnp(RIGHT) then conta_sel = (conta_sel + 1) % 3; som_clique() end

  if ui.btnp(BTN_Z) then
    if conta_opcoes[conta_sel + 1] == conta_resp then
      acertar_equacao()
    else
      som_erro()
      popup("ERROU! DRONES ATIVADOS", C_VERMELHO)
      shake = 5
      errar_equacao()
    end
    return
  end

  conta_timer = conta_timer - 1
  if conta_timer <= 0 then
    som_erro()
    popup("TEMPO ESGOTADO!", C_LARANJA)
    errar_equacao()
  end
end

-- ---- JOGO (ir até a porta; falha aleatória; fuga) ----
local function update_jogo()
  ui.cls(C_FUNDO)
  atualizar_player()
  atualizar_enxame()

  desenhar_fundo()
  desenhar_cena()
  if modo == M_PERSEGUICAO then desenhar_glitch(4) end
  desenhar_hud()

  if modo == M_NORMAL then
    -- sistema estável: a falha chega num momento aleatório
    -- (ou na hora, se o jogador chegar perto demais da porta)
    falha_timer = falha_timer - 1
    local dpx, dpy = player.x - porta.x, player.y - porta.y
    if falha_timer <= 0 or dpx * dpx + dpy * dpy < RAIO_GATILHO * RAIO_GATILHO then
      disparar_falha()
      return
    end

  elseif modo == M_PERSEGUICAO then
    -- drones perseguem até o sistema reiniciar
    fuga_timer = fuga_timer - 1
    if fuga_timer <= 0 then
      modo = M_REPARADO
      porta_aberta = true
      popup("SISTEMA REINICIADO!", C_VERDE)
      som_acerto()
    end
  end

  -- chegou na porta aberta
  if porta_aberta then
    local dpx = player.x - porta.x
    local dpy = player.y - porta.y
    if dpx * dpx + dpy * dpy < 20 * 20 then
      pontos = pontos + 100
      avancar_fase()
      return
    end
  end

  -- captura (só por drones acordados)
  if modo == M_PERSEGUICAO then
    for _, d in ipairs(drones) do
      if d.espera <= 0 then
        local ddx = d.x - player.x
        local ddy = d.y - player.y
        if ddx * ddx + ddy * ddy < CATCH_DIST * CATCH_DIST then
          som_erro()
          shake = 7
          nunca_morreu = false
          popup("CAPTURADO! DE NOVO", C_VERMELHO)
          iniciar_fase()   -- recomeça a fase: drones em repouso, nova falha aleatória
          return
        end
      end
    end
  end
end

-- ---- AVANÇAR FASE ----
avancar_fase = function()
  trans_t = 0
  trans_final = (fase >= TOTAL_FASES)
  if trans_final then
    -- fim do jogo: bônus
    if acertou_todas then pontos = pontos + 500 end
    if nunca_morreu then pontos = pontos + 500 end
    som_vitoria()
  end
  ir_para(TRANSICAO)
end

-- ---- TRANSIÇÃO (portas fecham, resumo do setor, portas abrem) ----
local function update_transicao()
  trans_t = trans_t + 1
  local t = trans_t
  local meio = math.floor(ALTURA / 2)

  ui.cls(C_FUNDO)

  if t <= TRANS_FECHA then
    -- as portas fecham sobre o setor concluído
    desenhar_fundo()
    desenhar_cena()
    desenhar_hud()
    desenhar_portoes(math.floor(meio * t / TRANS_FECHA))
    if t == 1 then som_acerto() end

  elseif t <= TRANS_FECHA + TRANS_TEXTO then
    -- portas fechadas: painel com o resumo
    local u = t - TRANS_FECHA
    desenhar_portoes(meio)
    ui.rectfill(70, 60, 410, 210, C_PRETO)
    ui.rect(70, 60, 410, 210, C_BRANCO)
    texto_central("SETOR " .. fase .. " CONCLUIDO", 78, C_VERDE)
    texto_central("+100 PONTOS", 94, C_AMARELO)

    if trans_final then
      if u > 25 then
        texto_central("SISTEMA RESTAURADO", 130, C_CIANO)
        texto_central("todos os setores reparados", 148, C_CINZA)
      end
    elseif u > 25 then
      texto_central("ENTRANDO NO SETOR " .. (fase + 1), 128, C_CIANO)
      local bw = 200
      local bx = math.floor((LARGURA - bw) / 2)
      local p = ui.mid(0, (u - 25) / (TRANS_TEXTO - 25), 1)
      ui.rectfill(bx, 146, bx + math.floor(bw * p), 154, C_CIANO)
      ui.rect(bx, 146, bx + bw, 154, C_CINZA)
      texto_central("> reiniciando defesas...", 170, C_CINZA)
    end

    if u == TRANS_TEXTO then
      if trans_final then
        ir_para(RESULTADO)
      else
        som_clique()
        fase = fase + 1
        iniciar_fase()        -- monta o novo setor (muda o estado para JOGO)
        ir_para(TRANSICAO)    -- mas ainda falta abrir as portas
      end
    end

  else
    -- portas abrem revelando o novo setor
    local v = t - TRANS_FECHA - TRANS_TEXTO
    desenhar_fundo()
    desenhar_cena()
    desenhar_hud()
    texto_central("SETOR " .. fase .. "/" .. TOTAL_FASES, 120, C_AMARELO)
    desenhar_portoes(meio - math.floor(meio * v / TRANS_ABRE))
    if v >= TRANS_ABRE then ir_para(JOGO) end
  end
end

-- ---- RESULTADO ----
local function update_resultado()
  ui.cls(C_FUNDO)
  texto_central("SISTEMA ESTAVEL!", 40, C_AMARELO)
  texto_central("todos os setores restaurados", 60, C_CIANO)
  texto_central("pontuacao final", 90, C_CINZA)
  texto_central(tostring(pontos), 110, C_AMARELO)
  if acertou_todas then texto_central("+500 bonus: nenhuma conta errada", 140, C_VERDE) end
  if nunca_morreu then texto_central("+500 bonus sem falha critica", 156, C_VERDE) end

  -- salva no ranking uma vez
  if not entrou_ranking and nome ~= "" then
    inserir_ranking(nome, pontos)
    salvar_ranking()
    entrou_ranking = true
  end

  texto_central("B: menu   X: jogar de novo", 230, C_CINZA)
  if ui.btnp(BTN_Z) then som_clique(); ir_para(MENU) end
  if ui.btnp(BTN_X) then som_clique(); nivel_sel = 0; ir_para(NIVEL) end
end

-- ---- RANKING ----
local function update_ranking()
  ui.cls(C_FUNDO)
  texto_central("RANKING (TOP 10)", 30, C_BRANCO)
  if #ranking == 0 then
    texto_central("ainda sem recordes", 120, C_CINZA)
  else
    for i = 1, #ranking do
      local e = ranking[i]
      local linha = i .. ". " .. e.nome
      ui.print(linha, 90, 55 + i * 18, (i == 1) and C_AMARELO or C_BRANCO)
      local pts = tostring(e.pontos)
      ui.print(pts, LARGURA - 90 - #pts * 6, 55 + i * 18, C_CIANO)
    end
  end
  texto_central("B: voltar", 230, C_CINZA)
  if ui.btnp(BTN_Z) then som_clique(); ir_para(MENU) end
end

-- ===== LOOP PRINCIPAL =====
function update(frame)
  frame_cont = frame
  for i = 1, #Palette do
    ui.palset(i - 1, Palette[i])
  end

  -- cada setor tem uma cor de fundo própria (menus usam a do setor 1)
  local em_jogo = (estado == JOGO or estado == CONTA or estado == TRANSICAO)
  ui.palset(C_FUNDO, FUNDOS[em_jogo and fase or 1] or FUNDOS[1])

  -- screen shake
  local ox, oy = 0, 0
  if shake > 0 then
    ox = rnd(-shake, shake)
    oy = rnd(-shake, shake)
    shake = shake - 1
  end
  if ox ~= 0 or oy ~= 0 then ui.camera(ox, oy) end

  if estado == MENU then update_menu()
  elseif estado == NOME then update_nome()
  elseif estado == NIVEL then update_nivel()
  elseif estado == CONTA then update_conta()
  elseif estado == JOGO then update_jogo()
  elseif estado == TRANSICAO then update_transicao()
  elseif estado == RESULTADO then update_resultado()
  elseif estado == RANKING then update_ranking()
  end

  if ox ~= 0 or oy ~= 0 then ui.camera() end

  if popup_timer > 0 then
    popup_timer = popup_timer - 1
    local py = 200 - (45 - popup_timer)
    texto_central(popup_txt, py, popup_cor)
  end
end
