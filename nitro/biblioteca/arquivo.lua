-- titulo: Ler e gravar arquivo
-- Usa o disco do computador. Caminho com barra inicial: /Download/teste.txt
local fs = component.proxy(computer.getBootAddress())

local hnd = fs.open("/Download/teste.txt", "w")
if hnd then
  fs.write(hnd, "linha 1\nlinha 2\n")
  fs.close(hnd)
end

local leitura = fs.open("/Download/teste.txt")
if leitura then
  local texto = fs.read(leitura, math.huge)
  fs.close(leitura)
  print(texto)
end
