import NonFungibleToken from "./NonFungibleToken.cdc"
import MetadataViews from "./MetadataViews.cdc"
import FungibleToken from "./FungibleToken.cdc"
import FreshmintMetadataViews from "./FreshmintMetadataViews.cdc"

pub contract funsocks_contract: NonFungibleToken {

    pub let version: String

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64)
    pub event Burned(id: UInt64, metadata: Metadata)

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let CollectionPrivatePath: PrivatePath
    pub let AdminStoragePath: StoragePath

    /// The total number of funsocks_contract NFTs that have been minted.
    ///
    pub var totalSupply: UInt64

    /// A list of royalty recipients that is attached to all NFTs
    /// minted by this contract.
    ///
    access(contract) let royalties: [MetadataViews.Royalty]
    
    /// Return the royalty recipients for this contract.
    ///
    pub fun getRoyalties(): [MetadataViews.Royalty] {
        return funsocks_contract.royalties
    }

    /// The collection-level metadata for all NFTs minted by this contract.
    ///
    pub let collectionMetadata: MetadataViews.NFTCollectionDisplay

    pub struct Metadata {

        /// The core metadata fields for a funsocks_contract NFT.
        ///
        pub let name: String
        pub let description: String
        pub let thumbnail: String

        /// Optional attributes for a funsocks_contract NFT.
        ///
        pub let attributes: {String: String}

        init(
            name: String,
            description: String,
            thumbnail: String,
            attributes: {String: String}
        ) {
            self.name = name
            self.description = description
            self.thumbnail = thumbnail

            self.attributes = attributes
        }
    }

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {

        pub let id: UInt64
        pub let metadata: Metadata

        init(metadata: Metadata) {
            self.id = self.uuid
            self.metadata = metadata
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Royalties>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return self.resolveDisplay(self.metadata)
                case Type<MetadataViews.Royalties>():
                    return self.resolveRoyalties()
            }

            return nil
        }

        pub fun resolveDisplay(_ metadata: Metadata): MetadataViews.Display {
            return MetadataViews.Display(
                name: metadata.name,
                description: metadata.description,
                thumbnail: FreshmintMetadataViews.ipfsFile(file: metadata.thumbnail)
            )
        }
        
        pub fun resolveRoyalties(): MetadataViews.Royalties {
            return MetadataViews.Royalties(funsocks_contract.getRoyalties())
        }
        
        destroy() {
            funsocks_contract.totalSupply = funsocks_contract.totalSupply - (1 as UInt64)

            // This contract includes metadata in the burn event so that off-chain systems
            // can retroactively index NFTs that were burned in past sporks.
            //
            emit Burned(id: self.id, metadata: self.metadata)
        }
    }

    /// This dictionary indexes NFTs by their mint ID.
    ///
    /// It is populated at mint time and used to prevent duplicate mints.
    /// The mint ID can be any unique string value,
    /// for example the hash of the NFT metadata.
    ///
    access(contract) var nftsByMintID: {String: UInt64}

    pub fun getNFTByMintID(mintID: String): UInt64? {
        return funsocks_contract.nftsByMintID[mintID]
    }

    pub resource interface funsocks_contractCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowfunsocks_contract(id: UInt64): &funsocks_contract.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow funsocks_contract reference: The ID of the returned reference is incorrect"
            }
        }
    }
    
    pub resource Collection: funsocks_contractCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        
        /// A dictionary of all NFTs in this collection indexed by ID.
        ///
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}
    
        init () {
            self.ownedNFTs <- {}
        }
    
        /// Remove an NFT from the collection and move it to the caller.
        ///
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) 
                ?? panic("Requested NFT to withdraw does not exist in this collection")
    
            emit Withdraw(id: token.id, from: self.owner?.address)
    
            return <- token
        }
    
        /// Deposit an NFT into this collection.
        ///
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @funsocks_contract.NFT
    
            let id: UInt64 = token.id
    
            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token
    
            emit Deposit(id: id, to: self.owner?.address)
    
            destroy oldToken
        }
    
        /// Return an array of the NFT IDs in this collection.
        ///
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }
    
        /// Return a reference to an NFT in this collection.
        ///
        /// This function panics if the NFT does not exist in this collection.
        ///
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }
    
        /// Return a reference to an NFT in this collection
        /// typed as funsocks_contract.NFT.
        ///
        /// This function returns nil if the NFT does not exist in this collection.
        ///
        pub fun borrowfunsocks_contract(id: UInt64): &funsocks_contract.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &funsocks_contract.NFT
            }
    
            return nil
        }
    
        /// Return a reference to an NFT in this collection
        /// typed as MetadataViews.Resolver.
        ///
        /// This function panics if the NFT does not exist in this collection.
        ///
        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let nftRef = nft as! &funsocks_contract.NFT
            return nftRef as &AnyResource{MetadataViews.Resolver}
        }
    
        destroy() {
            destroy self.ownedNFTs
        }
    }
    
    /// Return a new empty collection.
    ///
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    /// The administrator resource used to mint and reveal NFTs.
    ///
    pub resource Admin {

        /// Mint a new NFT.
        ///
        /// To mint an NFT, specify a value for each of its metadata fields.
        ///
        pub fun mintNFT(
            mintID: String,
            name: String,
            description: String,
            thumbnail: String,
            attributes: {String: String}
        ): @funsocks_contract.NFT {

            // Prevent multiple NFTs from being minted with the same mint ID
            assert(
                funsocks_contract.nftsByMintID[mintID] == nil,
                message: "an NFT has already been minted with mintID=".concat(mintID)
            )

            let metadata = Metadata(
                name: name,
                description: description,
                thumbnail: thumbnail,
                attributes: attributes
            )

            let nft <- create funsocks_contract.NFT(metadata: metadata)
   
            // Update the mint ID index
            funsocks_contract.nftsByMintID[mintID] = nft.id

            emit Minted(id: nft.id)

            funsocks_contract.totalSupply = funsocks_contract.totalSupply + (1 as UInt64)

            return <- nft
        }
    }

    /// Return a public path that is scoped to this contract.
    ///
    pub fun getPublicPath(suffix: String): PublicPath {
        return PublicPath(identifier: "funsocks_contract_".concat(suffix))!
    }

    /// Return a private path that is scoped to this contract.
    ///
    pub fun getPrivatePath(suffix: String): PrivatePath {
        return PrivatePath(identifier: "funsocks_contract_".concat(suffix))!
    }

    /// Return a storage path that is scoped to this contract.
    ///
    pub fun getStoragePath(suffix: String): StoragePath {
        return StoragePath(identifier: "funsocks_contract_".concat(suffix))!
    }

    /// Return a collection name with an optional bucket suffix.
    ///
    pub fun makeCollectionName(bucketName maybeBucketName: String?): String {
        if let bucketName = maybeBucketName {
            return "Collection_".concat(bucketName)
        }

        return "Collection"
    }

    /// Return a queue name with an optional bucket suffix.
    ///
    pub fun makeQueueName(bucketName maybeBucketName: String?): String {
        if let bucketName = maybeBucketName {
            return "Queue_".concat(bucketName)
        }

        return "Queue"
    }

    priv fun initAdmin(admin: AuthAccount) {
        // Create an empty collection and save it to storage
        let collection <- funsocks_contract.createEmptyCollection()

        admin.save(<- collection, to: funsocks_contract.CollectionStoragePath)

        admin.link<&funsocks_contract.Collection>(funsocks_contract.CollectionPrivatePath, target: funsocks_contract.CollectionStoragePath)

        admin.link<&funsocks_contract.Collection{NonFungibleToken.CollectionPublic, funsocks_contract.funsocks_contractCollectionPublic, MetadataViews.ResolverCollection}>(funsocks_contract.CollectionPublicPath, target: funsocks_contract.CollectionStoragePath)
        
        // Create an admin resource and save it to storage
        let adminResource <- create Admin()

        admin.save(<- adminResource, to: self.AdminStoragePath)
    }

    init(collectionMetadata: MetadataViews.NFTCollectionDisplay, royalties: [MetadataViews.Royalty]) {

        self.version = "0.7.0"

        self.CollectionPublicPath = funsocks_contract.getPublicPath(suffix: "Collection")
        self.CollectionStoragePath = funsocks_contract.getStoragePath(suffix: "Collection")
        self.CollectionPrivatePath = funsocks_contract.getPrivatePath(suffix: "Collection")

        self.AdminStoragePath = funsocks_contract.getStoragePath(suffix: "Admin")

        self.royalties = royalties
        self.collectionMetadata = collectionMetadata

        self.totalSupply = 0

        self.nftsByMintID = {}

        self.initAdmin(admin: self.account)

        emit ContractInitialized()
    }
}
