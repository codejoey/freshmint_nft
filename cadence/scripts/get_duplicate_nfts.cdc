import funsocks_contract from "../contracts/funsocks_contract.cdc"

pub fun main(mintIDs: [String]): [Bool] {
    let nfts: [Bool] = []

    for mintID in mintIDs {
        let exists = funsocks_contract.getNFTByMintID(mintID: mintID) != nil
        nfts.append(exists)
    }

    return nfts
}
