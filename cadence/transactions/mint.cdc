import funsocks_contract from "../contracts/funsocks_contract.cdc"

import NonFungibleToken from "../contracts/NonFungibleToken.cdc"
import MetadataViews from "../contracts/MetadataViews.cdc"
import FreshmintQueue from "../contracts/FreshmintQueue.cdc"

pub fun getOrCreateCollection(
    account: AuthAccount,
    bucketName: String?
): Capability<&NonFungibleToken.Collection> {

    let collectionName = funsocks_contract.makeCollectionName(bucketName: bucketName)

    let collectionPrivatePath = funsocks_contract.getPrivatePath(suffix: collectionName)

    let collectionCap = account.getCapability<&NonFungibleToken.Collection>(collectionPrivatePath)

    if collectionCap.check() {
        return collectionCap
    }

    // Create an empty collection if one does not exist

    let collection <- funsocks_contract.createEmptyCollection()

    let collectionStoragePath = funsocks_contract.getStoragePath(suffix: collectionName)
    let collectionPublicPath = funsocks_contract.getPublicPath(suffix: collectionName)

    account.save(<-collection, to: collectionStoragePath)

    account.link<&funsocks_contract.Collection>(collectionPrivatePath, target: collectionStoragePath)
    account.link<&funsocks_contract.Collection{NonFungibleToken.CollectionPublic, funsocks_contract.funsocks_contractCollectionPublic, MetadataViews.ResolverCollection}>(collectionPublicPath, target: collectionStoragePath)
    
    return collectionCap
}

pub fun getOrCreateMintQueue(
    account: AuthAccount,
    bucketName: String?
): &FreshmintQueue.CollectionQueue {

    let queueName = funsocks_contract.makeQueueName(bucketName: bucketName)

    let queuePrivatePath = funsocks_contract.getPrivatePath(suffix: queueName)

    // Check if a queue already exists with this name
    let queueCap = account.getCapability<&FreshmintQueue.CollectionQueue>(queuePrivatePath)
    if let queueRef = queueCap.borrow() {
        return queueRef
    }

    // Create a new queue if one does not exist

    let queue <- FreshmintQueue.createCollectionQueue(
        collection: getOrCreateCollection(account: account, bucketName: bucketName)
    )
    
    let queueRef = &queue as &FreshmintQueue.CollectionQueue

    let queueStoragePath = funsocks_contract.getStoragePath(suffix: queueName)
    
    account.save(<- queue, to: queueStoragePath)
    account.link<&FreshmintQueue.CollectionQueue>(queuePrivatePath, target: queueStoragePath)

    return queueRef
}

transaction(
    bucketName: String?,
    mintIDs: [String],
    name: [String],
    description: [String],
    thumbnail: [String],
) {
    
    let admin: &funsocks_contract.Admin
    let mintQueue: &FreshmintQueue.CollectionQueue

    prepare(signer: AuthAccount) {
        self.admin = signer.borrow<&funsocks_contract.Admin>(from: funsocks_contract.AdminStoragePath)
            ?? panic("Could not borrow a reference to the NFT admin")
        
        self.mintQueue = getOrCreateMintQueue(
            account: signer,
            bucketName: bucketName
        )
    }

    execute {

        for i, mintID in mintIDs {

            let token <- self.admin.mintNFT(
                mintID: mintID,
                name: name[i],
                description: description[i],
                thumbnail: thumbnail[i],
                attributes: {}
            )
        
            // NFTs are minted into a queue to preserve the mint order.
            // A CollectionQueue is linked to a collection. All NFTs minted into 
            // the queue are deposited into the underlying collection.
            //
            self.mintQueue.deposit(token: <- token)
        }
    }
}
