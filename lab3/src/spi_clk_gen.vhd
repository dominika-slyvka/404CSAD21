--------------------------------------------------------------------------------
-- Модуль      : spi_clk_gen
-- Призначення : Дільник тактової частоти для SPI Master.
--               Формує однотактовий строб half_tick з частотою 2 * SCK_FREQ,
--               тобто один імпульс на кожну половину періоду SCK.
--               Передавач по кожному half_tick перемикає лінію SCK.
--
-- Приклад     : CLK_FREQ = 25 МГц, SCK_FREQ = 500 кГц
--               DIVISOR = round(25e6 / (2 * 500e3)) = 25
--               фактична частота SCK = 25e6 / (25 * 2) = 500 кГц (0 %)
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_clk_gen is
    generic (
        CLK_FREQ : positive := 25_000_000;  -- частота системного такту, Гц
        SCK_FREQ : positive := 500_000      -- бажана частота SCK, Гц
    );
    port (
        clk       : in  std_logic;   -- системний тактовий сигнал
        rst       : in  std_logic;   -- синхронне скидання, активний '1'
        half_tick : out std_logic    -- строб 1 такт, 2*SCK_FREQ Гц
    );
end entity spi_clk_gen;

architecture rtl of spi_clk_gen is
    -- Коефіцієнт ділення з округленням до найближчого цілого
    constant DIVISOR : positive := (CLK_FREQ + SCK_FREQ) / (2 * SCK_FREQ);

    -- Лічильник тактів дільника: 0 .. DIVISOR-1
    signal cnt : natural range 0 to DIVISOR - 1 := 0;
begin

    divider : process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                cnt       <= 0;
                half_tick <= '0';
            elsif cnt = DIVISOR - 1 then
                cnt       <= 0;
                half_tick <= '1';
            else
                cnt       <= cnt + 1;
                half_tick <= '0';
            end if;
        end if;
    end process divider;

end architecture rtl;
