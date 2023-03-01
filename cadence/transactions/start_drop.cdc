import funsocks_contract from "../contracts/funsocks_contract.cdc"

import FreshmintClaimSaleV2 from "../contracts/FreshmintClaimSaleV2.cdc"
import FreshmintQueue from "../contracts/FreshmintQueue.cdc"
import FungibleToken from "../contracts/FungibleToken.cdc"
import NonFungibleToken from "../contracts/NonFungibleToken.cdc"
import MetadataViews from "../contracts/MetadataViews.cdc"

pub fun getOrCreateSaleCollection(account: AuthAccount): &FreshmintClaimSaleV2.SaleCollection {
    if let collectionRef = account.borrow<&FreshmintClaimSaleV2.SaleCollection>(from: FreshmintClaimSaleV2.SaleCollectionStoragePath) {
        return collectionRef
    }

    let collection <- FreshmintClaimSaleV2.createEmptySaleCollection()

    let collectionRef = &collection as &FreshmintClaimSaleV2.SaleCollection

    account.save(<-collection, to: FreshmintClaimSaleV2.SaleCollectionStoragePath)
    account.link<&FreshmintClaimSaleV2.SaleCollection{FreshmintClaimSaleV2.SaleCollectionPublic}>(FreshmintClaimSaleV2.SaleCollectionPublicPath, target: FreshmintClaimSaleV2.SaleCollectionStoragePath)
        
    return collectionRef
}

pub fun getAllowlist(account: AuthAccount, allowlistName: String): Capability<&FreshmintClaimSaleV2.Allowlist> {
    let fullAllowlistName = FreshmintClaimSaleV2.makeAllowlistName(name: allowlistName)

    let privatePath = funsocks_contract.getPrivatePath(suffix: fullAllowlistName)

    return account.getCapability<&FreshmintClaimSaleV2.Allowlist>(privatePath)
}

// This transaction starts a new claim sale.
//
// Parameters:
// - saleID: the ID of the sale.
// - price: the price to set for the sale.
// - collectionName: (optional) the collection name to claim from.
// - allowlistName: (optional) the name of the allowlist to attach to the sale.
//
transaction(
    saleID: String,
    price: UFix64,
    paymentReceiverAddress: Address?,
    paymentReceiverPath: PublicPath?,
    bucketName: String?,
    claimLimit: UInt?,
    allowlistName: String?
) {

    let sales: &FreshmintClaimSaleV2.SaleCollection
    let mintQueue: Capability<&{FreshmintQueue.Queue}>
    let paymentReceiver: Capability<&{FungibleToken.Receiver}>
    let allowlist: Capability<&FreshmintClaimSaleV2.Allowlist>?

    prepare(signer: AuthAccount) {

        self.sales = getOrCreateSaleCollection(account: signer)

        let queueName = funsocks_contract.makeQueueName(bucketName: bucketName)
        let queuePrivatePath = funsocks_contract.getPrivatePath(suffix: queueName)

        self.mintQueue = signer
            .getCapability<&{FreshmintQueue.Queue}>(queuePrivatePath)

        self.paymentReceiver = getAccount(paymentReceiverAddress ?? signer.address)
            .getCapability<&{FungibleToken.Receiver}>(paymentReceiverPath ?? /public/flowTokenReceiver)

        if let name = allowlistName {
            self.allowlist = getAllowlist(account: signer, allowlistName: name)
        } else {
            self.allowlist = nil
        }
    }

    execute {
        let sale <- FreshmintClaimSaleV2.createSale(
            id: saleID,
            queue: self.mintQueue,
            receiverPath: funsocks_contract.CollectionPublicPath,
            paymentReceiver: self.paymentReceiver,
            price: price,
            claimLimit: claimLimit,
            allowlist: self.allowlist
        )

        self.sales.insert(<- sale)
    }
}
