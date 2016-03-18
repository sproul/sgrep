class Sgrep
        attr_accessor :patt
        attr_accessor :beginning_of_significance
        attr_accessor :ending_of_significance
        attr_accessor :fn
        attr_accessor :f
        def initialize(beginning_of_significance, ending_of_significance, patt, fn)
                self.beginning_of_significance = beginning_of_significance
                self.ending_of_significance = ending_of_significance
                self.patt = Regexp.new(patt)
                self.fn = fn
                if !File.readable?(fn)
                        STDERR.puts "sgrep: #{fn}: No such file or directory"
                        exit(1)
                end
                self.f = File.open(fn, "r")
                puts "sgrep looking for \"#{patt}\" in file #{fn}, bounded by the significant region starting with \"#{beginning_of_significance}\" and ending with \"#{ending_of_significance}\"..." if Sgrep.trace
                #        header = fh.readline
                # Process the header
                #     while(line = fh.gets) != nil
                #         #do stuff
                #     end
                # end"@@
        end
        def search_sequentially_from(pos)
                if pos > 0
                        f.seek(pos-1, IO::SEEK_SET)
                        self.seek_next_line
                else
                        f.seek(pos, IO::SEEK_SET)
                end
                while !self.f.eof? do
                        next_line_start = self.f.tell
                        line = self.f.gets
                        if line.start_with?(self.beginning_of_significance) || line > self.beginning_of_significance
                                f.seek(next_line_start, IO::SEEK_SET)
                                puts "searched sequentially to #{next_line_start} (seeing #{line})" if Sgrep.trace
                                return
                        end
                end
        end
        def seek_beginning_of_significance()
                lower_bound = 0
                upper_bound = File.size(self.fn)
                puts "lower_bound=#{lower_bound}, upper_bound=#{upper_bound}" if Sgrep.trace
                while upper_bound > lower_bound do
                        midpoint = (lower_bound + ((upper_bound - lower_bound) / 2)).to_i
                        f.seek(midpoint, IO::SEEK_SET)
                        self.seek_next_line
                        next_line_start = self.f.tell
                        line = self.f.gets
                        puts "see #{line.chomp}, lower_bound=#{lower_bound}, upper_bound=#{upper_bound}, midpoint=#{midpoint}, next_line_start=#{next_line_start}" if Sgrep.trace
                        if line.start_with?(self.beginning_of_significance)
                                puts "match" if Sgrep.trace
                                if upper_bound > next_line_start
                                        upper_bound = next_line_start
                                else
                                        break
                                end
                        elsif line < self.beginning_of_significance
                                puts "under" if Sgrep.trace
                                lower_bound = self.f.tell+1
                        else
                                puts "over" if Sgrep.trace
                                upper_bound = midpoint-1
                        end
                end
                self.search_sequentially_from(lower_bound)
        end
        def seek_next_line()
                while !self.f.eof? do
                        if self.f.getc == "\n"
                                return
                        end
                end
        end
        def significant_lines
                while !self.f.eof? do
                        line = f.gets
                        if line.start_with?(self.ending_of_significance) || line < self.ending_of_significance
                                yield line
                        else
                                return
                        end
                end
                return
        end
        def search()
                #return `grep "#{self.patt}" #{self.fn}`
                self.seek_beginning_of_significance

                exit_code = 1
                self.significant_lines do | line |
                        if self.patt.match(line)
                                exit_code = 0
                                print line
                        end
                end
                return exit_code
        end
        class << self
                attr_accessor :trace
        end
end

j = 0
while ARGV[j].start_with?("-") do
        case ARGV[j]
        when "-v"
                Sgrep.trace = true
        end
        j += 1
end
beginning_of_significance = ARGV[j]
ending_of_significance = ARGV[j+1]
patt = ARGV[j+2]
fn = ARGV[j+3]
g = Sgrep.new(beginning_of_significance, ending_of_significance, patt, fn)
exit(g.search())
