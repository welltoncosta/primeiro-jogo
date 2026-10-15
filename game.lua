-- ============================================================
--  MENTE AFIADA  —  Treino Cerebral para o Lupi
--  Game Jam do Lupi · Latinoware 2026
--  Tema: educação, jogos, estratégia mental e inteligência
--
--  Um "ginásio do cérebro" com 3 provas:
--    1) MEMÓRIA  — repita a sequência de cores (Simon)
--    2) CÁLCULO  — resolva contas de cabeça contra o tempo
--    3) REFLEXO  — controle o impulso (aperte só no verde)
--
--  Controles: D-pad (setas) + Z (confirmar) + X (voltar)
-- ============================================================

-- ===== PALETA (formato RGB555 — registrada a cada frame) =====
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
}

-- ===== CONSTANTES =====
-- estados
local TITULO, MENU, MEMORIA, CALCULO, REACAO, RESULTADO = 0,1,2,3,4,5

-- cores (índices da paleta)
local C_PRETO, C_FUNDO, C_BRANCO = 0,1,2
local C_VERMELHO, C_VERDE, C_AMARELO = 3,4,5
local C_AZUL, C_CIANO, C_MAGENTA, C_CINZA = 6,7,8,9
local C_LARANJA, C_VERDE_CLARO, C_CINZA_ESCURO = 10,11,12

-- ===== ESTADO GLOBAL =====
local estado = TITULO
local score_total = 0

-- efeitos visuais
local shake = 0
local popup_txt, popup_cor, popup_timer = nil, 0, 0

-- título
local titulo_pulso = 0

-- menu
local menu_sel = 0
local MENU_ITENS = { "MEMORIA", "CALCULO", "REFLEXO" }

-- memória (Simon)
local mem_seq, mem_len, mem_idx, mem_fase, mem_fase_timer, mem_erros
local mem_flash, mem_flash_timer
local mem_botao = { -- posições dos 4 botões (diamante): UP, RIGHT, DOWN, LEFT
  { x=240, y=95,  c=C_VERDE,    b=UP },
  { x=310, y=135, c=C_VERMELHO, b=RIGHT },
  { x=240, y=175, c=C_AMARELO,  b=DOWN },
  { x=170, y=135, c=C_AZUL,     b=LEFT },
}

-- cálculo
local calc_a, calc_b, calc_op, calc_resp, calc_opcoes, calc_sel, calc_feitas, calc_acertos, calc_timer

-- reflexo
local reac_estado, reac_timer, reac_alvo_verde, reac_rodadas, reac_acertos, reac_falhas

-- ===== HELPERS =====
local function texto_central(t, y, cor)
  local w = #t * 6  -- estimativa ~6px por caractere (fonte mono)
  ui.print(t, math.floor((480 - w) / 2), y, cor)
end

local function texto_direita(t, x, y, cor)
  local w = #t * 6
  ui.print(t, x - w, y, cor)
end

local function popup(txt, cor)
  popup_txt, popup_cor, popup_timer = txt, cor, 45
end

local function nota(n)
  sfx.fx(0, n, 0.5)  -- bip curto (sample 0); ajuste se necessário
end

local function som_acerto()  nota(72) end
local function som_erro()    nota(40) end
local function som_clique()  nota(60) end

local function ir_para(novo)
  estado = novo
end

local function novo_jogo()
  score_total = 0
  menu_sel = 0
end

local function desenha_fundo()
  -- faixa de cabeçalho
  ui.rectfill(0, 0, 480, 26, C_CINZA_ESCURO)
  ui.print("MENTE AFIADA", 8, 7, C_BRANCO)
  texto_direita("PONTOS " .. score_total, 472, 7, C_AMARELO)
end

-- ===== TÍTULO =====
local function titulo_init()
  titulo_pulso = 0
end

local function titulo_update(frame)
  titulo_pulso = titulo_pulso + 1
  ui.cls(C_FUNDO)

  local py = 70 + math.sin(titulo_pulso / 18) * 4
  -- cérebro estilizado (círculo + fendas)
  ui.circfill(240, py + 30, 42, C_VERMELHO_CLARO)
  ui.circfill(240, py + 30, 30, C_MAGENTA)
  ui.line(200, py + 30, 240, py + 6, C_FUNDO)
  ui.line(280, py + 30, 240, py + 6, C_FUNDO)
  ui.line(240, py + 30, 240, py + 54, C_FUNDO)
  ui.circfill(210, py + 22, 6, C_FUNDO)
  ui.circfill(270, py + 22, 6, C_FUNDO)

  texto_central("MENTE AFIADA", py + 78, C_BRANCO)
  texto_central("treine memoria, calculo e reflexo", py + 96, C_CINZA)

  if (math.floor(titulo_pulso / 20)) % 2 == 0 then
    texto_central("PRESSIONE Z PARA COMECAR", 225, C_AMARELO)
  end

  if ui.btnp(BTN_Z) then
    som_clique()
    ir_para(MENU)
  end
end

-- ===== MENU =====
local function menu_update(frame)
  ui.cls(C_FUNDO)
  desenha_fundo()

  if ui.btnp(DOWN) then menu_sel = (menu_sel + 1) % 3; som_clique() end
  if ui.btnp(UP) then menu_sel = (menu_sel - 1) % 3; som_clique() end

  for i = 1, 3 do
    local y = 60 + i * 42
    local cor = C_CINZA
    if i - 1 == menu_sel then cor = C_AMARELO end
    if i - 1 == menu_sel then ui.rectfill(150, y - 14, 330, y + 14, C_CINZA_ESCURO) end
    texto_central(MENU_ITENS[i], y - 3, cor)
  end

  texto_central("setas: escolher   Z: entrar", 210, C_CINZA)

  if ui.btnp(BTN_Z) then
    som_clique()
    if menu_sel == 0 then
      mem_init(); ir_para(MEMORIA)
    elseif menu_sel == 1 then
      calc_init(); ir_para(CALCULO)
    else
      reac_init(); ir_para(REACAO)
    end
  end
end

-- ===== 1) MEMÓRIA (Simon) =====
local function mem_init()
  mem_len = 3
  mem_seq = {}
  mem_idx = 1
  mem_erros = 0
  mem_fase = 0          -- 0 = mostrando, 1 = jogador, 2 = acerto (pausa), 3 = erro/fim
  mem_fase_timer = 0
  mem_flash = 0
  mem_flash_timer = 0
  -- gera a primeira sequência
  for i = 1, 32 do mem_seq[i] = math.random(1, 4) end
end

local function mem_desenha_botao(b, aceso)
  local r = 22
  local cor = b.c
  if aceso then
    ui.circfill(b.x, b.y, r + 4, C_BRANCO)
    ui.circfill(b.x, b.y, r, cor)
  else
    ui.circfill(b.x, b.y, r, cor)
    ui.circ(b.x, b.y, r, C_CINZA_ESCURO)
  end
end

local function mem_update(frame)
  ui.cls(C_FUNDO)
  desenha_fundo()
  texto_central("MEMORIA — repita a sequencia", 36, C_CIANO)
  texto_central("rodada " .. (mem_len - 2), 54, C_CINZA)

  -- desenha os 4 botões (diamante)
  for i = 1, 4 do
    local aceso = false
    if mem_fase == 0 then
      -- mostrando: acende o botão atual da sequência
      aceso = (mem_idx <= mem_len and mem_seq[mem_idx] == i)
    elseif mem_fase == 1 then
      -- jogador acabou de apertar (feedback visual)
      aceso = (mem_flash == i and mem_flash_timer > 0)
    end
    mem_desenha_botao(mem_botao[i], aceso)
  end

  if mem_fase == 0 then
    -- FASE: mostrar sequência
    mem_fase_timer = mem_fase_timer + 1
    if mem_fase_timer >= 30 then
      mem_fase_timer = 0
      mem_idx = mem_idx + 1
      if mem_idx > mem_len then
        mem_fase = 1   -- passa para o jogador
        mem_idx = 1
        mem_fase_timer = 0
      end
    end
  elseif mem_fase == 1 then
    -- FASE: jogador repete
    if mem_flash_timer > 0 then mem_flash_timer = mem_flash_timer - 1 end
    for i = 1, 4 do
      if ui.btnp(mem_botao[i].b) then
        mem_flash = i
        mem_flash_timer = 10
        if mem_seq[mem_idx] == i then
          som_acerto()
          mem_idx = mem_idx + 1
          if mem_idx > mem_len then
            -- completou a rodada
            local pts = mem_len * 10
            score_total = score_total + pts
            popup("+" .. pts, C_VERDE)
            mem_len = mem_len + 1
            mem_idx = 1
            mem_fase = 0
            mem_fase_timer = 0
          end
        else
          som_erro()
          mem_erros = mem_erros + 1
          popup("ERROU!", C_VERMELHO)
          shake = 6
          if mem_erros >= 3 then
            mem_fase = 3
          else
            -- mostra a sequência de novo
            mem_idx = 1
            mem_fase = 0
            mem_fase_timer = 0
          end
        end
      end
    end
    -- dica de controles
    texto_central("use as setas (cima/direita/baixo/esquerda)", 235, C_CINZA)
  elseif mem_fase == 3 then
    texto_central("FIM — voce errou 3 vezes", 130, C_VERMELHO)
    texto_central("Z para continuar", 150, C_CINZA)
    if ui.btnp(BTN_Z) then ir_para(RESULTADO); resultado_init("memoria") end
  end
end

-- ===== 2) CÁLCULO =====
local function calc_gerar()
  calc_op = math.random(0, 1) -- 0 = +, 1 = -
  if calc_op == 0 then
    calc_a = math.random(2, 50)
    calc_b = math.random(2, 50)
    calc_resp = calc_a + calc_b
  else
    calc_a = math.random(10, 99)
    calc_b = math.random(2, calc_a - 1)
    calc_resp = calc_a - calc_b
  end
  -- 3 opções (1 correta + 2 próximas)
  local d1 = math.random(1, 6) * (math.random(0,1) == 0 and 1 or -1)
  local d2 = math.random(1, 6) * (math.random(0,1) == 0 and 1 or -1)
  local op = { calc_resp, calc_resp + d1, calc_resp + d2 }
  -- embaralha
  for i = 3, 2, -1 do
    local j = math.random(1, i)
    op[i], op[j] = op[j], op[i]
  end
  calc_opcoes = op
  calc_sel = 0
  calc_timer = 60 * 8  -- 8 segundos por conta
end

local function calc_init()
  calc_feitas = 0
  calc_acertos = 0
  calc_gerar()
end

local function calc_update(frame)
  ui.cls(C_FUNDO)
  desenha_fundo()
  texto_central("CALCULO — resolva de cabeca", 36, C_CIANO)
  texto_central("acertos " .. calc_acertos .. "/" .. calc_feitas, 54, C_CINZA)

  -- barra de tempo
  local bw = 300
  local bx = math.floor((480 - bw) / 2)
  local proporcao = calc_timer / (60 * 8)
  ui.rectfill(bx, 70, bx + math.floor(bw * proporcao), 78, C_LARANJA)
  ui.rect(bx, 70, bx + bw, 78, C_CINZA)

  -- pergunta
  local sinal = (calc_op == 0) and "+" or "-"
  texto_central(calc_a .. " " .. sinal .. " " .. calc_b .. " = ?", 100, C_BRANCO)

  -- 3 opções
  for i = 0, 2 do
    local x = 110 + i * 100
    local cor = C_CINZA
    if i == calc_sel then cor = C_AMARELO end
    if i == calc_sel then ui.rectfill(x - 40, 130, x + 40, 158, C_CINZA_ESCURO) end
    ui.print(tostring(calc_opcoes[i + 1]), x - 8, 142, cor)
  end

  if ui.btnp(LEFT) then calc_sel = (calc_sel - 1) % 3; som_clique() end
  if ui.btnp(RIGHT) then calc_sel = (calc_sel + 1) % 3; som_clique() end

  if ui.btnp(BTN_Z) then
    calc_feitas = calc_feitas + 1
    if calc_opcoes[calc_sel + 1] == calc_resp then
      calc_acertos = calc_acertos + 1
      local pts = 15
      score_total = score_total + pts
      popup("+" .. pts, C_VERDE)
      som_acerto()
      if calc_feitas >= 10 then
        ir_para(RESULTADO); resultado_init("calculo")
      else
        calc_gerar()
      end
    else
      popup("ERROU!", C_VERMELHO)
      som_erro()
      shake = 5
    end
  end

  -- tempo esgotado
  calc_timer = calc_timer - 1
  if calc_timer <= 0 then
    popup("TEMPO!", C_LARANJA)
    som_erro()
    calc_feitas = calc_feitas + 1
    if calc_feitas >= 10 then
      ir_para(RESULTADO); resultado_init("calculo")
    else
      calc_gerar()
    end
  end
end

-- ===== 3) REFLEXO (controle de impulso) =====
local function reac_init()
  reac_rodadas = 0
  reac_acertos = 0
  reac_falhas = 0
  reac_estado = 0   -- 0 = esperando, 1 = mostrando alvo
  reac_timer = 0
  reac_alvo_verde = true
end

local function reac_nova_rodada()
  reac_alvo_verde = (math.random(1, 100) <= 70)  -- 70% verde (aperte), 30% vermelho (não aperte)
  reac_estado = 1
  reac_timer = 0
end

local function reac_update(frame)
  ui.cls(C_FUNDO)
  desenha_fundo()
  texto_central("REFLEXO — aperte Z so no VERDE", 36, C_CIANO)
  texto_central("rodada " .. reac_rodadas .. "/8", 54, C_CINZA)

  local cor_alvo = reac_alvo_verde and C_VERDE or C_VERMELHO

  if reac_estado == 0 then
    texto_central("prepare...", 140, C_CINZA)
    reac_timer = reac_timer + 1
    if reac_timer > 40 then reac_nova_rodada() end
  else
    -- alvo aparece
    ui.circfill(240, 150, 40, cor_alvo)
    if reac_alvo_verde then
      ui.print("APERTE!", 212, 142, C_BRANCO)
    else
      ui.print("NAO APERTE", 196, 142, C_BRANCO)
    end

    reac_timer = reac_timer + 1

    local acertou = nil
    if ui.btnp(BTN_Z) then
      acertou = reac_alvo_verde
      if acertou then
        som_acerto(); popup("CERTO!", C_VERDE)
        reac_acertos = reac_acertos + 1
        score_total = score_total + 10
      else
        som_erro(); popup("IMPULSO!", C_VERMELHO); shake = 6
        reac_falhas = reac_falhas + 1
      end
    elseif reac_timer > 50 then
      -- tempo esgotou (não apertou)
      acertou = not reac_alvo_verde
      if acertou then
        som_acerto(); popup("CERTO!", C_VERDE)
        reac_acertos = reac_acertos + 1
        score_total = score_total + 10
      else
        som_erro(); popup("PERDEU!", C_VERMELHO); shake = 6
        reac_falhas = reac_falhas + 1
      end
    end

    if acertou ~= nil then
      reac_rodadas = reac_rodadas + 1
      reac_estado = 0
      reac_timer = 0
      if reac_rodadas >= 8 then
        ir_para(RESULTADO); resultado_init("reflexo")
      end
    end
  end
end

-- ===== RESULTADO =====
local resultado_jogo = ""

local function resultado_init(jogo)
  resultado_jogo = jogo
end

local function resultado_update(frame)
  ui.cls(C_FUNDO)

  local classificacao, cor_class
  if score_total >= 250 then
    classificacao, cor_class = "GENIO!", C_AMARELO
  elseif score_total >= 180 then
    classificacao, cor_class = "MENTE AFIADA!", C_VERDE
  elseif score_total >= 120 then
    classificacao, cor_class = "BOM CEREBRO!", C_CIANO
  else
    classificacao, cor_class = "CONTINUE TREINANDO!", C_CINZA
  end

  texto_central("RESULTADO", 50, C_BRANCO)
  texto_central("pontuacao total", 80, C_CINZA)
  texto_central(tostring(score_total), 105, C_AMARELO)
  texto_central(classificacao, 140, cor_class)

  texto_central("Z: jogar de novo   X: menu", 200, C_CINZA)

  if ui.btnp(BTN_Z) then
    novo_jogo(); ir_para(MENU)
  elseif ui.btnp(BTN_X) then
    novo_jogo(); ir_para(TITULO)
  end
end

-- ===== LOOP PRINCIPAL =====
function update(frame)
  -- registra a paleta a cada frame (obrigatório no Lupi)
  for i = 1, #Palette do
    ui.palset(i - 1, Palette[i])
  end

  -- screen shake
  local ox, oy = 0, 0
  if shake > 0 then
    ox = math.random(-shake, shake)
    oy = math.random(-shake, shake)
    shake = shake - 1
  end
  if ox ~= 0 or oy ~= 0 then ui.camera(ox, oy) end

  -- despacha para o estado atual
  if estado == TITULO then
    titulo_update(frame)
  elseif estado == MENU then
    menu_update(frame)
  elseif estado == MEMORIA then
    mem_update(frame)
  elseif estado == CALCULO then
    calc_update(frame)
  elseif estado == REACAO then
    reac_update(frame)
  elseif estado == RESULTADO then
    resultado_update(frame)
  end

  if ox ~= 0 or oy ~= 0 then ui.camera() end

  -- popup de feedback (desenhado por cima)
  if popup_timer > 0 then
    popup_timer = popup_timer - 1
    local py = 200 - (45 - popup_timer)
    texto_central(popup_txt, py, popup_cor)
  end
end
