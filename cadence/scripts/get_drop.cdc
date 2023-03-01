import FreshmintClaimSaleV2 from "../contracts/FreshmintClaimSaleV2.cdc"

// This script returns the information about an active claim sale.
//
// Parameters:
// - saleAddress: the address of the account holding the sale.
// - saleID: the ID of the sale within the account.
//
pub fun main(saleAddress: Address, saleID: String): FreshmintClaimSaleV2.SaleInfo? {
    if let saleCollection = getAccount(saleAddress)
        .getCapability(FreshmintClaimSaleV2.SaleCollectionPublicPath)
        .borrow<&{FreshmintClaimSaleV2.SaleCollectionPublic}>() {

        if let sale = saleCollection.borrowSale(id: saleID) {
            return sale.getInfo()
        }
    }

    return nil
}
