-- ============================================================
--  SISTEMA CRITICO  —  jogo para o Lupi (arquivo: drones.lua)
--  Game Jam do Lupi · Latinoware 2026
--  Tema: FALHA NO SISTEMA
--
--  Você pilota um DRONE PRETO. Cada setor tem uma comporta travada
--  por um CÓDIGO DE REPARO (conta matemática). Acertou? A comporta
--  abre. Errou (ou o tempo acabou)? O SISTEMA FALHA e o enxame de 6
--  drones de defesa enlouquece e persegue você — fuja até o sistema
--  REINICIAR (8s) e escape.
--
--  O enxame usa BOIDS com parâmetros evoluídos por um Algoritmo
--  Genético (ver treinar_drones.py). O melhor genoma está embutido
--  na constante GENOMA abaixo.
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
local TITULO, MENU, NOME, NIVEL, CONTA, FUGA, RESULTADO, RANKING = 0,1,2,3,4,5,6,7

-- cores
local C_PRETO, C_FUNDO, C_BRANCO = 0,1,2
local C_VERMELHO, C_VERDE, C_AMARELO = 3,4,5
local C_AZUL, C_CIANO, C_MAGENTA, C_CINZA = 6,7,8,9
local C_LARANJA, C_VERDE_CLARO, C_CINZA_ESCURO = 10,11,12

-- jogo
local LARGURA, ALTURA = 480, 270
local PLAYER_SPEED = 3.6
local CATCH_DIST = 9
local N_DRONES = 6
local HACK_FRAMES = 480   -- 8 segundos a 60 FPS
local TOTAL_FASES = 5
local TEMPO_CONTA = 600   -- 10 segundos

-- ===== ESTADO GLOBAL =====
local estado = TITULO
local frame_cont = 0

-- título (para semear o random)
local titulo_frames = 0

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
      return a .. "^" .. b .. " = ?", a ^ b
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

-- ===== INÍCIO DE FUGA =====
local function iniciar_fuga()
  player = { x = rnd(60, LARGURA - 60), y = rnd(60, ALTURA - 60), vx = 0, vy = 0 }
  drones = {}
  local cx, cy = rnd(30, LARGURA - 30), rnd(30, ALTURA - 30)
  for _ = 1, N_DRONES do
    drones[#drones + 1] = {
      x = clamp(cx + rnd(-25, 25), 8, LARGURA - 8),
      y = clamp(cy + rnd(-25, 25), 8, ALTURA - 8),
      vx = 0, vy = 0,
    }
  end
  local edge = rnd(0, 3)
  if edge == 0 then porta = { x = rnd(0, LARGURA), y = 10 }
  elseif edge == 1 then porta = { x = rnd(0, LARGURA), y = ALTURA - 10 }
  elseif edge == 2 then porta = { x = 10, y = rnd(0, ALTURA) }
  else porta = { x = LARGURA - 10, y = rnd(0, ALTURA) } end
  fuga_timer = HACK_FRAMES
  porta_aberta = false
  acertou_todas = false   -- drones apareceram
  ir_para(FUGA)
end

-- ===== ENXAME (Boids com GENOMA) =====
local function atualizar_enxame()
  for i, d in ipairs(drones) do
    local sep_x, sep_y = 0, 0
    local ali_x, ali_y = 0, 0
    local coh_x, coh_y = 0, 0
    local n = 0
    for j, o in ipairs(drones) do
      if i ~= j then
        local dx = d.x - o.x
        local dy = d.y - o.y
        local dist2 = dx * dx + dy * dy
        if dist2 < 1600 then -- 40^2
          local dist = math.sqrt(dist2) + 0.01
          sep_x = sep_x + dx / dist
          sep_y = sep_y + dy / dist
          ali_x = ali_x + o.vx
          ali_y = ali_y + o.vy
          coh_x = coh_x + o.x
          coh_y = coh_y + o.y
          n = n + 1
        end
      end
    end
    if n > 0 then
      ali_x = ali_x / n
      ali_y = ali_y / n
      coh_x = coh_x / n - d.x
      coh_y = coh_y / n - d.y
    end
    local px = player.x + player.vx * GENOMA.predict
    local py = player.y + player.vy * GENOMA.predict
    local skx = px - d.x
    local sky = py - d.y
    local sl = math.sqrt(skx * skx + sky * sky) + 0.01
    skx = skx / sl
    sky = sky / sl

    d.vx = d.vx + GENOMA.cohesion * coh_x + GENOMA.separation * sep_x
                 + GENOMA.alignment * ali_x + GENOMA.seek * skx
    d.vy = d.vy + GENOMA.cohesion * coh_y + GENOMA.separation * sep_y
                 + GENOMA.alignment * ali_y + GENOMA.seek * sky

    local sp = math.sqrt(d.vx * d.vx + d.vy * d.vy)
    if sp > GENOMA.max_speed then
      d.vx = d.vx / sp * GENOMA.max_speed
      d.vy = d.vy / sp * GENOMA.max_speed
    end
    d.x = clamp(d.x + d.vx, 8, LARGURA - 8)
    d.y = clamp(d.y + d.vy, 8, ALTURA - 8)
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
local function desenhar_drone(x, y, cor, raio)
    -- 1. Braços cruzados (formato X)
    local offset = raio + 3
    ui.line(x - offset, y - offset, x + offset, y + offset, C_CINZA)
    ui.line(x - offset, y + offset, x + offset, y - offset, C_CINZA)

    -- 2. Corpo central
    ui.circfill(x, y, raio, cor)

    -- 3. As 4 hélices nas pontas dos braços
    ui.circfill(x - offset, y - offset, 2, C_BRANCO)
    ui.circfill(x + offset, y - offset, 2, C_BRANCO)
    ui.circfill(x - offset, y + offset, 2, C_BRANCO)
    ui.circfill(x + offset, y + offset, 2, C_BRANCO)
end

-- ===== TELAS =====

local function update_titulo()
  titulo_frames = titulo_frames + 1
  ui.cls(C_FUNDO)

  -- drones decorativos ao fundo (visual)
  for i = 1, 3 do
    local x = 80 + i * 110
    local y = 150 + math.sin(titulo_frames / 20 + i) * 20
    desenhar_drone(x, y, C_CINZA_ESCURO, 6)
  end

  texto_central("SISTEMA CRITICO", 40, C_BRANCO)
  texto_central("> inicializando nucleo...", 70, C_CINZA)
  texto_central("> modulos de defesa: ativos", 84, C_CINZA)
  texto_central("! FALHA DETECTADA - repare o sistema", 102, C_VERMELHO)
  texto_central("d-pad: mover · B: confirmar · X: voltar", 210, C_CINZA)

  if (math.floor(titulo_frames / 20)) % 2 == 0 then
    texto_central("PRESSIONE B PARA INICIAR", 235, C_AMARELO)
  end

  if ui.btnp(BTN_Z) then
    -- semear o random com base em quanto tempo ficou na tela
    math.randomseed(titulo_frames * 7919 + 1)
    som_clique()
    ir_para(MENU)
  end
end

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
    iniciar_conta()
  end
  if ui.btnp(BTN_X) then som_clique(); ir_para(MENU) end
end

-- ---- AVANÇAR FASE (forward declaration) ----
local avancar_fase

-- ---- CONTA ----
local function update_conta()
  ui.cls(C_FUNDO)
  -- cabeçalho
  ui.rectfill(0, 0, LARGURA, 26, C_CINZA_ESCURO)
  ui.print("FASE " .. fase .. "/" .. TOTAL_FASES, 8, 7, C_CIANO)
  local pts_txt = "PONTOS " .. pontos
  ui.print(pts_txt, LARGURA - 6 - #pts_txt * 6, 7, C_AMARELO)

  texto_central("REPARE O SISTEMA - INSIRA O CODIGO", 40, C_BRANCO)
  -- timer (barra)
  local bw = 320
  local bx = math.floor((LARGURA - bw) / 2)
  local proporcao = conta_timer / TEMPO_CONTA
  ui.rectfill(bx, 56, bx + math.floor(bw * proporcao), 64, C_LARANJA)
  ui.rect(bx, 56, bx + bw, 64, C_CINZA)

  -- pergunta
  texto_central(conta_texto, 90, C_BRANCO)

  -- opções
  for i = 0, 2 do
    local x = 110 + i * 100
    local cor = (i == conta_sel) and C_AMARELO or C_CINZA
    if i == conta_sel then ui.rectfill(x - 40, 120, x + 40, 148, C_CINZA_ESCURO) end
    ui.print(tostring(conta_opcoes[i + 1]), x - 8, 130, cor)
  end

  if ui.btnp(LEFT) then conta_sel = (conta_sel - 1) % 3; som_clique() end
  if ui.btnp(RIGHT) then conta_sel = (conta_sel + 1) % 3; som_clique() end

  if ui.btnp(BTN_Z) then
    if conta_opcoes[conta_sel + 1] == conta_resp then
      -- acertou
      local bonus = math.floor(conta_timer / TEMPO_CONTA * 100)
      local pts = 100 + bonus
      pontos = pontos + pts
      popup("+" .. pts, C_VERDE)
      som_acerto()
      avancar_fase()
    else
      som_erro()
      popup("ERROU!", C_VERMELHO)
      shake = 5
      iniciar_fuga()
    end
  end

  conta_timer = conta_timer - 1
  if conta_timer <= 0 then
    som_erro()
    popup("TEMPO!", C_LARANJA)
    iniciar_fuga()
  end
end

-- ---- FUGA ----
local function update_fuga()
  ui.cls(C_FUNDO)
  atualizar_player()
  atualizar_enxame()

  -- desenha a porta
  local cor_porta = porta_aberta and C_VERDE or C_CINZA
  ui.rectfill(porta.x - 14, porta.y - 14, porta.x + 14, porta.y + 14, cor_porta)
  if not porta_aberta then
    ui.rect(porta.x - 14, porta.y - 14, porta.x + 14, porta.y + 14, C_VERMELHO)
  end

  -- desenha os drones brancos
  for _, d in ipairs(drones) do
    desenhar_drone(d.x, d.y, C_BRANCO, 6)
  end

  -- desenha o jogador (drone preto)
  desenhar_drone(player.x, player.y, C_PRETO, 7)
  ui.circ(player.x, player.y, 7, C_AMARELO)

  -- ===== efeito de glitch (sistema falhando) =====
  if not porta_aberta then
    for _ = 1, 4 do
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

  -- barra de reinício do sistema
  local bw = 200
  local bx = math.floor((LARGURA - bw) / 2)
  local proporcao = 1 - (fuga_timer / HACK_FRAMES)
  texto_central("REINICIANDO SISTEMA...", 4, C_CIANO)
  ui.rectfill(bx, 16, bx + math.floor(bw * proporcao), 24, C_CIANO)
  ui.rect(bx, 16, bx + bw, 24, C_CINZA)
  if not porta_aberta and (math.floor(frame_cont / 15)) % 2 == 0 then
    texto_central("! DEFESAS INSTAVEIS - ERR 0x07F", 30, C_VERMELHO)
  end

  -- lógica do reinício
  if fuga_timer > 0 then
    fuga_timer = fuga_timer - 1
    if fuga_timer == 0 then
      porta_aberta = true
      popup("SISTEMA REINICIADO!", C_VERDE)
      som_acerto()
    end
  end

  -- escape
  if porta_aberta then
    local dpx = player.x - porta.x
    local dpy = player.y - porta.y
    if dpx * dpx + dpy * dpy < 20 * 20 then
      pontos = pontos + 100
      popup("+100", C_VERDE)
      avancar_fase()
      return
    end
  end

  -- captura
  for _, d in ipairs(drones) do
    local ddx = d.x - player.x
    local ddy = d.y - player.y
    if ddx * ddx + ddy * ddy < CATCH_DIST * CATCH_DIST then
      som_erro()
      shake = 7
      nunca_morreu = false
      popup("FALHA CRITICA!", C_VERMELHO)
      -- reinicia a fase (nova conta)
      iniciar_conta()
      return
    end
  end
end

-- ---- AVANÇAR FASE ----
avancar_fase = function()
  if fase >= TOTAL_FASES then
    -- fim do jogo: bônus + resultado
    if acertou_todas then
      pontos = pontos + 500
    end
    if nunca_morreu then
      pontos = pontos + 500
    end
    som_vitoria()
    ir_para(RESULTADO)
  else
    fase = fase + 1
    iniciar_conta()
  end
end

-- ---- RESULTADO ----
local function update_resultado()
  ui.cls(C_FUNDO)
  texto_central("SISTEMA ESTAVEL!", 40, C_AMARELO)
  texto_central("todos os setores restaurados", 60, C_CIANO)
  texto_central("pontuacao final", 90, C_CINZA)
  texto_central(tostring(pontos), 110, C_AMARELO)
  if acertou_todas then texto_central("+500 bonus perfeito (sem falhas)", 140, C_VERDE) end
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

  -- screen shake
  local ox, oy = 0, 0
  if shake > 0 then
    ox = rnd(-shake, shake)
    oy = rnd(-shake, shake)
    shake = shake - 1
  end
  if ox ~= 0 or oy ~= 0 then ui.camera(ox, oy) end

  if estado == TITULO then update_titulo()
  elseif estado == MENU then update_menu()
  elseif estado == NOME then update_nome()
  elseif estado == NIVEL then update_nivel()
  elseif estado == CONTA then update_conta()
  elseif estado == FUGA then update_fuga()
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
