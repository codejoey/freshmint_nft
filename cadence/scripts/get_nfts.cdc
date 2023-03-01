import funsocks_contract from "../contracts/funsocks_contract.cdc"
import NonFungibleToken from "../contracts/NonFungibleToken.cdc"

pub fun main(address: Address): [UInt64] {
    if let col = getAccount(address).getCapability<&funsocks_contract.Collection{NonFungibleToken.CollectionPublic}>(funsocks_contract.CollectionPublicPath).borrow() {
        return col.getIDs()
    }

    return []
}
