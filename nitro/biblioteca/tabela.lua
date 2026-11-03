-- titulo: Tabela e laco for
-- Lista de itens: percorre, soma e filtra.
local itens = { "maca", "banana", "uva" }
for i, nome in ipairs(itens) do
  print(i, nome)
end

local pontos = { alice = 10, bruno = 7 }
for nome, valor in pairs(pontos) do
  print(nome, valor)
end
