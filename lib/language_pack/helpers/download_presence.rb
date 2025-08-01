# This class is used to check whether a binary exists on one or more stacks.
# The main motivation for adding this logic is to help people who are upgrading
# to a new stack if it does not have a given Ruby version. For example if someone
# is using Ruby 1.9.3 on the cedar-14 stack then they should be informed that it
# does not exist if they try to use it on the Heroku-18 stack.
#
# Example
#
#    download = LanguagePack::Helpers::DownloadPresence.new(
#      'ruby-3.1.7.tgz',
#      stacks: ['heroku-22', 'heroku-24']
#    )
#
#    download.call
#
#    puts download.exists? #=> true
#    puts download.valid_stack_list #=> ['heroku-22', 'heroku-24']
class LanguagePack::Helpers::DownloadPresence
  # heroku-22 and heroku-24 have identical ruby versions supported
  STACKS = ['heroku-22', 'heroku-24']

  def initialize(file_name:, arch: , multi_arch_stacks:, stacks: STACKS )
    @file_name = file_name

    # Special case: Ruby 2.6.6 is only available on heroku-20, not heroku-22
    # Check heroku-20 availability when requesting heroku-22
    if file_name == "ruby-2.6.6.tgz"
      @stacks = stacks.map { |stack| (stack == "heroku-22" || stack == "heroku-24") ? "heroku-20" : stack }
    else
      @stacks = stacks
    end

    @fetchers = []
    @threads = []
    @stacks.each do |stack|
      if multi_arch_stacks.include?(stack)
        @fetchers << LanguagePack::Fetcher.new(LanguagePack::Base::VENDOR_URL, stack: stack, arch: arch)
      else
        @fetchers << LanguagePack::Fetcher.new(LanguagePack::Base::VENDOR_URL, stack: stack)
      end
    end
  end

  def supported_stack?(current_stack: )
    @stacks.include?(current_stack)
  end

  def next_stack(current_stack: )
    return unless supported_stack?(current_stack: current_stack)

    next_index = @stacks.index(current_stack) + 1
    @stacks[next_index]
  end

  def exists_on_next_stack?(current_stack: )
    return false unless supported_stack?(current_stack: current_stack)

    next_index = @stacks.index(current_stack) + 1
    @threads[next_index].value
  end

  def valid_stack_list
    raise "not invoked yet, use the `call` method first" if @threads.empty?

    @threads.map.with_index do |thread, i|
      @stacks[i] if thread.value
    end.compact
  end

  def exists?
    raise "not invoked yet, use the `call` method first" if @threads.empty?

    @threads.any? {|t| t.value }
  end

  def does_not_exist?
    !exists?
  end

  def call
    @fetchers.map do |fetcher|
      @threads << Thread.new do
        fetcher.exists?(@file_name, 3)
      end
    end
  end
end
