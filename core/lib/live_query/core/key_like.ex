defprotocol LiveQuery.Core.KeyLike do
  def child_spec(key, opts)
end
