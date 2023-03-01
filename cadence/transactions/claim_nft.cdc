import funsocks_contract from "../contracts/funsocks_contract.cdc"

import FreshmintClaimSaleV2 from "../contracts/FreshmintClaimSaleV2.cdc"
import FungibleToken from "../contracts/FungibleToken.cdc"
import NonFungibleToken from "../contracts/NonFungibleToken.cdc"
import MetadataViews from "../contracts/MetadataViews.cdc"
import FlowToken from "../contracts/FlowToken.cdc"

pub fun intializeCollection(account: AuthAccount) {
    if account.borrow<&funsocks_contract.Collection>(from: funsocks_contract.CollectionStoragePath) == nil {
        let collection <- funsocks_contract.createEmptyCollection()
        
        account.save(<-collection, to: funsocks_contract.CollectionStoragePath)

        account.link<&funsocks_contract.Collection{NonFungibleToken.CollectionPublic, funsocks_contract.funsocks_contractCollectionPublic, MetadataViews.ResolverCollection}>(
            funsocks_contract.CollectionPublicPath, 
            target: funsocks_contract.CollectionStoragePath
        )
    }
}

// This transaction claims an NFT from a sale.
//
// Parameters:
// - saleAddress: the address of the account holding the sale.
// - saleID: the ID of the sale within the account.
//
transaction(saleAddress: Address, saleID: String) {

    let address: Address
    let payment: @FungibleToken.Vault
    let sale: &{FreshmintClaimSaleV2.SalePublic}

    prepare(signer: AuthAccount) {
        intializeCollection(account: signer)

        self.address = signer.address

        self.sale = getAccount(saleAddress)
            .getCapability(FreshmintClaimSaleV2.SaleCollectionPublicPath)!
            .borrow<&{FreshmintClaimSaleV2.SaleCollectionPublic}>()!
            .borrowSale(id: saleID)!

        let vault = signer
            .borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Cannot borrow FLOW vault from account storage")

        let price = self.sale.price
   
        self.payment <- vault.withdraw(amount: price)
    }

    execute {
        self.sale.claim(payment: <- self.payment, address: self.address)
    }
}
