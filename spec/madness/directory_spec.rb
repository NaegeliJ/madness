describe Directory do
  subject { described_class.new docroot }

  before do
    config.reset
    config.path = 'spec/fixtures/docroot/Sorting'
  end

  describe '#tree' do
    before do
      config.reset
      config.path = 'spec/fixtures/nav'
    end

    it 'attaches recursive children to directory items' do
      tree = subject.tree
      folder = tree.find { |i| i.label == 'Folder' }

      expect(folder).to be_a(Item)
      expect(folder.dir?).to be true
      expect(folder.children).to be_an(Array)
      expect(folder.children.map(&:label)).to eq ['Nested']
    end

    it 'leaves file items without children' do
      tree = subject.tree
      file = tree.find { |i| i.label == 'XFile' }

      expect(file.file?).to be true
      expect(file.children).to be_nil
    end
  end

  describe '#list' do
    it 'returns a naturally sorted array of Items' do
      list = subject.list

      expect(list).to be_an Array
      expect(list.count).to eq 7
      expect(list.first).to be_an Item
      expect(list.last.label).to eq 'Last File'
    end

    it 'omits files that are named like an existing directory' do
      list = subject.list.map { |item| File.basename item.path }

      expect(list).to include '5. Covered Folder'
      expect(list).not_to include '5. Covered Folder.md'
    end

    context 'when expose_extensions is set' do
      before do
        config.reset
        config.path = 'spec/fixtures/expose-extensions'
        config.expose_extensions = 'pdf,txt'
      end

      it 'also lists the files with the exposed extensions' do
        list = subject.list

        expect(list).to be_an Array
        expect(list.count).to eq 5
        expect(list.first).to be_an Item
        expect(list.first.label).to eq 'A dummy PDF file.pdf'
        expect(list.last.label).to eq 'Some dummy TXT file.txt'
      end
    end

    context 'when exclude is set' do
      before do
        config.reset
        config.path = 'spec/fixtures/exclude'
        config.exclude = %w[Ignore pub.ic]
      end

      it 'excludes directories based on the exclusion array' do
        list = subject.list

        expect(list).to be_an Array
        expect(list.count).to eq 2
        expect(list.first.label).to eq 'Folder'
        expect(list.last.label).to eq 'lowercase'
      end
    end
  end
end
