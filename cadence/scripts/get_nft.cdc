import funsocks_contract from "../contracts/funsocks_contract.cdc"
import NonFungibleToken from "../contracts/NonFungibleToken.cdc"
import MetadataViews from "../contracts/MetadataViews.cdc"
import FreshmintMetadataViews from "../contracts/FreshmintMetadataViews.cdc"

pub struct NFT {
    pub let id: UInt64

    pub let display: MetadataViews.Display
    pub let hash: String?
    
    init(
        id: UInt64,
        display: MetadataViews.Display,
        hash: String?
    ) {
        self.id = id
        self.display = display
        self.hash = hash
    }
}

pub fun main(address: Address, id: UInt64): NFT? {
    if let col = getAccount(address).getCapability<&funsocks_contract.Collection{NonFungibleToken.CollectionPublic, funsocks_contract.funsocks_contractCollectionPublic}>(funsocks_contract.CollectionPublicPath).borrow() {
        if let nft = col.borrowfunsocks_contract(id: id) {

            let display = nft.resolveView(Type<MetadataViews.Display>())! as! MetadataViews.Display

            var hash: String? = nil

            if let blindNFTView = nft.resolveView(Type<FreshmintMetadataViews.BlindNFT>()) {
                let blindNFT = blindNFTView as! FreshmintMetadataViews.BlindNFT
                hash = String.encodeHex(blindNFT.hash)
            }

            return NFT(
                id: id,
                display: display,
                hash: hash
            )
        }
    }

    return nil
}
