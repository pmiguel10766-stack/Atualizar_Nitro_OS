-- titulo: Tratar clique
-- Dentro de onTouch(self, x, y, nitro). Retorne true se tratou o clique.
local bx, by, bw, bh = self.x + 3, self.y + 4, 10, 1
if x >= bx and x < bx + bw and y == by then
  -- clicou no botao
  return true
end
return false
