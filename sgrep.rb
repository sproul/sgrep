class Sgrep
        attr_accessor :patt
        attr_accessor :beginning_of_significance
        attr_accessor :ending_of_significance
        attr_accessor :fn
        # if both beginning_of_significance and ending_of_significance are numerical, then consider all non-numerical line beginnings to indicate a multi-line log
        # entry (e.g., a stacktrace)
        attr_accessor :all_lines_begin_with_digits
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
                self.f = File.open(fn, "r", :encoding => "BINARY")
                self.log "sgrep looking for \"#{patt}\" in file #{fn}, bounded by the significant region starting with \"#{beginning_of_significance}\" and ending with \"#{ending_of_significance}\"..."
                #        header = fh.readline
                # Process the header
                #     while(line = fh.gets) != nil
                #         #do stuff
                #     end
                # end"
        end
        def log(x)
                if Sgrep.trace
                        STDERR.puts x
                end
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
                        # if beginning_of_significance is not unique on lines, we may be missing significant lines above.
                        # Normally I feel okay about this in that the boundary is likely to be chosen to be a least one second before the true window of interest.
                        if line.start_with?(self.beginning_of_significance) || line > self.beginning_of_significance
                                f.seek(next_line_start, IO::SEEK_SET)
                                self.log "searched sequentially to #{next_line_start} (seeing #{line})"
                                return
                        end
                end
        end
        def seek_beginning_of_significance()
                lower_bound = 0
                upper_bound = File.size(self.fn)
                self.log "lower_bound=#{lower_bound}, upper_bound=#{upper_bound}"
                while upper_bound > lower_bound do
                        midpoint = (lower_bound + ((upper_bound - lower_bound) / 2)).to_i
                        f.seek(midpoint, IO::SEEK_SET)
                        self.seek_next_line
                        next_line_start = self.f.tell
                        self.log("about to call gets_possible_multiline")
                        line = self.gets_possible_multiline
                        break unless line
                        self.log "see #{line.chomp}, lower_bound=#{lower_bound}, upper_bound=#{upper_bound}, midpoint=#{midpoint}, next_line_start=#{next_line_start}"
                        if line.start_with?(self.beginning_of_significance)
                                self.log "match"
                                if upper_bound > next_line_start
                                        upper_bound = next_line_start
                                else
                                        break
                                end
                        elsif line < self.beginning_of_significance
                                self.log "under"
                                lower_bound = self.f.tell+1
                        else
                                self.log "over"
                                upper_bound = midpoint-1
                        end
                end
                self.search_sequentially_from(lower_bound)
        end
        def seek_next_line()
                while !self.f.eof? do
                        if self.f.getc == "\n"
                                if self.f.eof?
                                        return
                                end
                                if self.all_lines_begin_with_digits
                                        # verify that we aren't in a multiline log msg (e.g., a stack trace)
                                        next_char = self.f.getc
                                        if next_char =~ /[[:digit:]]/
                                                # assume that this is a new timestamp
                                                self.f.seek(-1, IO::SEEK_CUR)
                                                return
                                        else
                                                next
                                        end
                                end
                                return
                        end
                end
        end
        def gets_possible_multiline()
                # This routine acts like gets except that if it detects a log entry which has multiple lines (e.g., a stack trace), then it
                # appends them together into a single string
                if !self.all_lines_begin_with_digits
                        # all_lines_begin_with_digits usually tells us if the file's log entries begin with a numerical time stamp.  I use
                        # this info to detect multiple line log entries (e.g., stack traces).  If all_lines_begin_with_digits is false, then
                        # I really don't know anything about the format of the lines, so I should just pass thru to gets():
                        x = self.f.gets
                        log("gets_possible_multiline passed on '#{x}'")
                        return x
                end
                if self.f.eof?
                        log("gets_possible_multiline saw EOF")
                        return nil
                end
                possible_multiline = self.f.gets
                while !self.f.eof? do
                        line_start_pos = self.f.tell()
                        line = self.f.gets
                        if line !~ /^\d/
                                possible_multiline << line
                        else
                                self.f.seek(line_start_pos, IO::SEEK_SET)
                                break
                        end
                end
                log("gets_possible_multiline saw '#{possible_multiline}'")
                return possible_multiline
        end
        def significant_lines
                loop do
                        line = self.gets_possible_multiline
                        if !line
                                break
                        elsif line.start_with?(self.ending_of_significance) || line < self.ending_of_significance
                                log "significant_lines yielding #{line}"
                                yield line
                        else
                                self.log "ending search now that I have seen '#{line}' (which is past '#{self.ending_of_significance}')"
                                return
                        end
                end
                self.log "reached EOF without reaching self.ending_of_significance=#{self.ending_of_significance}"
                return
        end
        def search()
                if self.beginning_of_significance   =~ /^\d/ && self.ending_of_significance =~ /^\d/
                        self.log("self.all_lines_begin_with_digits = true (because of #{self.beginning_of_significance} or #{self.ending_of_significance})")
                        self.all_lines_begin_with_digits = true
                end
                
                log("search()")
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
