# frozen_string_literal: true

RSpec.describe Api::Rest::Admin::ContractorsController, type: :controller do
  let(:user) { create :admin_user }
  let(:auth_token) { ::Knock::AuthToken.new(payload: { sub: user.id }).token }

  before do
    request.accept = 'application/vnd.api+json'
    request.headers['Content-Type'] = 'application/vnd.api+json'
    request.headers['Authorization'] = auth_token
  end

  describe 'GET index' do
    let!(:contractors) { create_list :contractor, 2, vendor: true }

    before { get :index }

    it { expect(response.status).to eq(200) }
    it { expect(response_data.size).to eq(contractors.size) }
  end

  describe 'GET index with associations filter' do
    before { create_list :contractor, 2, vendor: true }
    let(:smtp_connection) { wrap_relationship(:'smtp-connections', create(:smtp_connection).id) }

    subject(:contractor) { Contractor.where(smtp_connection_id: smtp_connection) }
    it { expect(contractor).to contain_exactly(*Contractor.where(smtp_connection_id: smtp_connection).to_a) }
  end

  describe 'GET index with filters' do
    before { create_list :contractor, 2, vendor: true }

    it_behaves_like :jsonapi_filter_by_name do
      let(:subject_record) { create(:contractor, vendor: true) }
    end
  end

  describe 'GET index with ransack filters' do
    let(:factory) { :vendor }

    it_behaves_like :jsonapi_filters_by_string_field, :name
    it_behaves_like :jsonapi_filters_by_boolean_field, :enabled
    it_behaves_like :jsonapi_filters_by_string_field, :description
    it_behaves_like :jsonapi_filters_by_string_field, :address
    it_behaves_like :jsonapi_filters_by_string_field, :phones
    it_behaves_like :jsonapi_filters_by_number_field, :external_id

    describe 'filter by "customer" field' do
      include_context :ransack_filter_setup
      context 'equal operator' do
        let(:filter_key) { 'customer_eq' }
        let(:filter_value) { true }
        let!(:suitable_record) { create :customer }
        let!(:other_record) { create :vendor }

        before { subject_request }

        it { is_expected.to include suitable_record.id.to_s }
        it { is_expected.not_to include other_record.id.to_s }
      end

      context 'not equal operator' do
        let(:filter_key) { 'customer_not_eq' }
        let(:filter_value) { true }
        let!(:suitable_record) { create :vendor }
        let!(:other_record) { create :customer }

        before { subject_request }

        it { is_expected.to include suitable_record.id.to_s }
        it { is_expected.not_to include other_record.id.to_s }
      end
    end

    describe 'filter by "vendor" field' do
      include_context :ransack_filter_setup
      context 'equal operator' do
        let(:filter_key) { 'vendor_eq' }
        let(:filter_value) { false }
        let!(:suitable_record) { create :customer }
        let!(:other_record) { create :vendor }

        before { subject_request }

        it { is_expected.to include suitable_record.id.to_s }
        it { is_expected.not_to include other_record.id.to_s }
      end

      context 'not equal operator' do
        let(:filter_key) { 'vendor_not_eq' }
        let(:filter_value) { false }
        let!(:suitable_record) { create :vendor }
        let!(:other_record) { create :customer }

        before { subject_request }

        it { is_expected.to include suitable_record.id.to_s }
        it { is_expected.not_to include other_record.id.to_s }
      end
    end
  end

  describe 'GET show' do
    let!(:contractor) { create :contractor, vendor: true }

    context 'when contractor exists' do
      before { get :show, params: { id: contractor.to_param } }

      it { expect(response.status).to eq(200) }
      it { expect(response_data['id']).to eq(contractor.id.to_s) }
    end

    context 'when contractor does not exist' do
      before { get :show, params: { id: contractor.id + 10 } }

      it { expect(response.status).to eq(404) }
      it { expect(response_data).to eq(nil) }
    end
  end

  describe 'POST create' do
    before do
      post :create, params: {
        data: { type: 'contractors',
                attributes: attributes,
                relationships: relationships }
      }
    end

    context 'when attributes are valid' do
      let(:attributes) { { name: 'name', vendor: true, 'external-id': 100 } }

      let(:relationships) do
        { 'smtp-connection': wrap_relationship(:'smtp-connections', create(:smtp_connection).id) }
      end

      it { expect(response.status).to eq(201) }
      it { expect(Contractor.count).to eq(1) }
    end

    context 'when attributes are invalid' do
      let(:attributes) { { vendor: false, customer: false } }
      let(:relationships) { {} }

      it { expect(response.status).to eq(422) }
      it { expect(Contractor.count).to eq(0) }
    end
  end

  describe 'PUT update' do
    let!(:contractor) { create :contractor, vendor: true }
    before do
      put :update, params: {
        id: contractor.to_param, data: { type: 'contractors', id: contractor.to_param, attributes: attributes }
      }
    end

    context 'when attributes are valid' do
      let(:attributes) { { name: 'name' } }

      it { expect(response.status).to eq(200) }
      it { expect(contractor.reload.name).to eq('name') }
    end

    context 'when attributes are invalid' do
      let(:attributes) { { vendor: false, customer: false } }

      it { expect(response.status).to eq(422) }
      it { expect(contractor.reload.vendor).to_not eq(false) }
    end

    context 'when attributes are not updatable' do
      let(:attributes) { { 'external-id': 200 } }

      it { expect(response.status).to eq(400) }
      it { expect(contractor.reload.external_id).to_not eq(200) }
    end
  end

  describe 'DELETE destroy' do
    let!(:contractor) { create :contractor, vendor: true }

    before { delete :destroy, params: { id: contractor.to_param } }

    it { expect(response.status).to eq(204) }
    it { expect(Contractor.count).to eq(0) }
  end
end
