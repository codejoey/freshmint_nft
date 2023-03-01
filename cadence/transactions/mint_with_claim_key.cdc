import funsocks_contract from "../contracts/funsocks_contract.cdc"

import NonFungibleToken from "../contracts/NonFungibleToken.cdc"
import MetadataViews from "../contracts/MetadataViews.cdc"
import FreshmintLockBox from "../contracts/FreshmintLockBox.cdc"

pub fun getOrCreateLockBox(
    account: AuthAccount,
    lockBoxStoragePath: StoragePath,
    lockBoxPublicPath: PublicPath,
    collectionPrivatePath: PrivatePath
): &FreshmintLockBox.LockBox {
    if let existingLockBox = account.borrow<&FreshmintLockBox.LockBox>(from: lockBoxStoragePath) {
        return existingLockBox
    }

    let collection = account.getCapability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(collectionPrivatePath)

    let lockBox <- FreshmintLockBox.createLockBox(
        collection: collection,
        receiverPath: funsocks_contract.CollectionPublicPath
    )

    let lockBoxRef = &lockBox as &FreshmintLockBox.LockBox

    account.save(<- lockBox, to: lockBoxStoragePath)

    account.link<&FreshmintLockBox.LockBox{FreshmintLockBox.LockBoxPublic}>(
        lockBoxPublicPath, 
        target: lockBoxStoragePath
    )

    return lockBoxRef
}

transaction(
    publicKeys: [String],
    mintIDs: [String],
    name: [String],
    description: [String],
    thumbnail: [String],
) {
    
    let admin: &funsocks_contract.Admin
    let lockBox: &FreshmintLockBox.LockBox

    prepare(signer: AuthAccount) {
        self.admin = signer
            .borrow<&funsocks_contract.Admin>(from: funsocks_contract.AdminStoragePath)
            ?? panic("Could not borrow a reference to the NFT admin")
        
        self.lockBox = getOrCreateLockBox(
            account: signer,
            lockBoxStoragePath: funsocks_contract.getStoragePath(suffix: "LockBox"),
            lockBoxPublicPath: funsocks_contract.getPublicPath(suffix: "LockBox"),
            collectionPrivatePath: funsocks_contract.CollectionPrivatePath
        )
    }

    execute {        
        for i, publicKey in publicKeys {

            let token <- self.admin.mintNFT(
                mintID: mintIDs[i],
                name: name[i],
                description: description[i],
                thumbnail: thumbnail[i],
            )
        
            self.lockBox.deposit(
                token: <- token, 
                publicKey: publicKey.decodeHex()
            )
        }
    }
}
