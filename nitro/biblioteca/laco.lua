-- titulo: Laco com pausa (nao trava o computador)
-- Todo laco infinito precisa de uma pausa dentro.
local cp = computer
local ultimo = cp.uptime()
while true do
  local ev, _, a, b, c = cp.pullSignal(0.5)  -- espera ate 0.5 s por um evento
  if ev == "key_down" and a == 1 then break end  -- Esc sai
  if cp.uptime() - ultimo >= 1 then
    ultimo = cp.uptime()
    -- algo que acontece a cada segundo
  end
end
