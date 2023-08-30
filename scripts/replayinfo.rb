class Replayinfo < Sandbox::Script
  def main
    if @args[0].nil?
      @logger.log("Specify replay ID")
      return
    end
    id = @args[0].to_i

    begin
      info = @game.cmdFightGetReplayInfo(id)
    rescue Trickster::Hackers::RequestError => e
      @logger.error(e)
      return
    end

    unless info["ok"]
      @logger.error("No such replay")
      return
    end

    @shell.custom_puts("Replay info: #{id}")
    @shell.custom_puts(" %-15s %s" % ["Datetime", info["datetime"]])
    @shell.custom_puts(" %-15s %s%s%s" % [
      "Success",
      info["success"] & Trickster::Hackers::Game::SUCCESS_CORE == 0 ? "\u25b3" : "\e[32m\u25b2\e[0m",
      info["success"] & Trickster::Hackers::Game::SUCCESS_RESOURCES == 0 ? "\u25b3" : "\e[32m\u25b2\e[0m",
      info["success"] & Trickster::Hackers::Game::SUCCESS_CONTROL == 0 ? "\u25b3" : "\e[32m\u25b2\e[0m",
    ])
    @shell.custom_puts(" %-15s %+d" % ["Rank", info["rank"]])
    @shell.custom_puts(" %-15s %d" % ["Money", info["money"]])
    @shell.custom_puts(" %-15s %d" % ["Bitcoins", info["bitcoins"]])
    @shell.custom_puts(" %-15s %s" % ["Test", info["test"]])
    @shell.custom_puts(" Attacker:")
    @shell.custom_puts("  %-15s %d" % ["ID", info["attacker"]["id"]])
    @shell.custom_puts("  %-15s %s" % ["Name", info["attacker"]["name"]])
    @shell.custom_puts("  %-15s %d (%s)" % ["Country", info["attacker"]["country"], @game.getCountryNameByID(info["attacker"]["country"])])
    @shell.custom_puts("  %-15s %d" % ["Level", info["attacker"]["level"]])
    @shell.custom_puts(" Target:")
    @shell.custom_puts("  %-15s %d" % ["ID", info["target"]["id"]])
    @shell.custom_puts("  %-15s %s" % ["Name", info["target"]["name"]])
    @shell.custom_puts("  %-15s %d (%s)" % ["Country", info["target"]["country"], @game.getCountryNameByID(info["target"]["country"])])
    @shell.custom_puts("  %-15s %d" % ["Level", info["target"]["level"]])
  end
end

