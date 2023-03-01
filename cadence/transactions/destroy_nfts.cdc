import NonFungibleToken from "../contracts/NonFungibleToken.cdc"
import funsocks_contract from "../contracts/funsocks_contract.cdc"

/// This transaction withdraws multiple NFTs from the signer's collection and destroys them.
///
transaction(ids: [UInt64], fromBucketName: String?) {

    /// A reference to the signer's funsocks_contract collection.
    ///
    let collectionRef: &funsocks_contract.Collection

    prepare(signer: AuthAccount) {
        
        // Derive the collection path from the bucket name
        let collectionName = funsocks_contract.makeCollectionName(bucketName: fromBucketName)
        let collectionStoragePath = funsocks_contract.getStoragePath(suffix: collectionName)

        self.collectionRef = signer.borrow<&funsocks_contract.Collection>(from: collectionStoragePath)
            ?? panic("failed to borrow collection")
    }

    execute {
        for id in ids {
            // withdraw the NFT from the signers's collection
            let nft <- self.collectionRef.withdraw(withdrawID: id)

            destroy nft
        }
    }
}
