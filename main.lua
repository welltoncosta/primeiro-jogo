-- Paleta de cores (RGB555) - índices 0 a 99
Palette = {
    0x0000, 0x0000, 0x0022, 0x02FF, 0x6FF7, 0x7EE7, 0x0001, 0x5FF7,
    0x2D00, 0x01F5, 0x3F7F, 0x2108, 0x5B5E, 0x4620, 0x00CA, 0x3DEF,
    -- ... continue com mais cores até o índice 99
}

-- Inicialização (executa uma vez ao carregar)
player = { x = 240, y = 135 }

function loop(frame)
  -- Registra a paleta de cores (necessário a cada frame)
  for i = 1, #Palette do
    ui.palset(i - 1, Palette[i])
  end
  
  -- Limpa a tela com cor azul escuro (índice 1)
  ui.cls(1)
  
  -- Desenha texto e retângulo
  ui.print("Ola Mundo! Frame: " .. frame, 120, 130, 7)
  ui.rectfill(50, 50, 100, 100, 8)
  
  -- Movimento do jogador
  if ui.btn(LEFT) then player.x = player.x - 2 end
  if ui.btn(RIGHT) then player.x = player.x + 2 end
  
  -- Desenha o jogador
  ui.circfill(player.x, player.y, 8, 7)
end
