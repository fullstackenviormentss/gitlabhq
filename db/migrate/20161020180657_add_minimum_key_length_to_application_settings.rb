class AddMinimumKeyLengthToApplicationSettings < ActiveRecord::Migration
  include Gitlab::Database::MigrationHelpers

  # Set this constant to true if this migration requires downtime.
  DOWNTIME = false

  disable_ddl_transaction!

  def up
    # A key restriction has two possible states:
    #
    #   * -1 means "this key type is completely disabled"
    #   * >= 0 means "keys must have at least this many bits to be valid"
    #
    # A value of 0 is equivalent to "there are no restrictions on keys of this type"
    add_column_with_default :application_settings, :rsa_key_restriction, :integer, default: 0
    add_column_with_default :application_settings, :dsa_key_restriction, :integer, default: 0
    add_column_with_default :application_settings, :ecdsa_key_restriction, :integer, default: 0
    add_column_with_default :application_settings, :ed25519_key_restriction, :integer, default: 0
  end

  def down
    remove_column :application_settings, :rsa_key_restriction
    remove_column :application_settings, :dsa_key_restriction
    remove_column :application_settings, :ecdsa_key_restriction
    remove_column :application_settings, :ed25519_key_restriction
  end
end
