require 'spec_helper'

describe Ci::RetryBuildService, :services do
  let(:user) { create(:user) }
  let(:project) { create(:empty_project) }
  let(:pipeline) { create(:ci_pipeline, project: project) }
  let(:build) { create(:ci_build, pipeline: pipeline) }

  let(:service) do
    described_class.new(project, user)
  end

  shared_examples 'build duplication' do
    let(:build) do
      create(:ci_build, :failed, :artifacts,
               pipeline: pipeline,
               coverage: 90.0,
               coverage_regex: '/(d+)/')
    end

    it 'clones expected attributes' do
      clone_attributes = %w[ref tag project pipeline options commands tag_list
                            name allow_failure stage stage_idx trigger_request
                            yaml_variables when environment coverage_regex]

      clone_attributes.each do |attribute|
        expect(new_build.send(attribute)).to eq build.send(attribute)
      end
    end

    it 'does not clone forbidden attributes' do
      forbidden_attributes = %w[id status token user artifacts_file
                                artifacts_metadata coverage]

      forbidden_attributes.each do |attribute|
        expect(new_build.send(attribute)).not_to eq build.send(attribute)
      end
    end
  end

  describe '#execute' do
    let(:new_build) { service.execute(build) }

    context 'when user has ability to execute build' do
      before do
        project.add_developer(user)
      end

      it_behaves_like 'build duplication'

      it 'creates a new build that represents the old one' do
        expect(new_build.name).to eq build.name
      end

      it 'enqueues the new build' do
        expect(new_build).to be_pending
      end

      it 'resolves todos for old build that failed' do
        expect(MergeRequests::AddTodoWhenBuildFailsService)
          .to receive_message_chain(:new, :close)

        service.execute(build)
      end

      context 'when there are subsequent builds that are skipped' do
        let!(:subsequent_build) do
          create(:ci_build, :skipped, stage_idx: 1, pipeline: pipeline)
        end

        it 'resumes pipeline processing in subsequent stages' do
          service.execute(build)

          expect(subsequent_build.reload).to be_created
        end
      end
    end

    context 'when user does not have ability to execute build' do
      it 'raises an error' do
        expect { service.execute(build) }
          .to raise_error Gitlab::Access::AccessDeniedError
      end
    end
  end

  describe '#reprocess' do
    let(:new_build) { service.reprocess(build) }

    context 'when user has ability to execute build' do
      before do
        project.add_developer(user)
      end

      it_behaves_like 'build duplication'

      it 'creates a new build that represents the old one' do
        expect(new_build.name).to eq build.name
      end

      it 'does not enqueue the new build' do
        expect(new_build).to be_created
      end
    end

    context 'when user does not have ability to execute build' do
      it 'raises an error' do
        expect { service.reprocess(build) }
          .to raise_error Gitlab::Access::AccessDeniedError
      end
    end
  end
end
