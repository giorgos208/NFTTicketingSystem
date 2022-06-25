// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 < 0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

library Base64 { // https://github.com/Brechtpd/base64/blob/main/base64.sol Base64 encoding and decoding
    string internal constant TABLE_ENCODE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    bytes  internal constant TABLE_DECODE = hex"0000000000000000000000000000000000000000000000000000000000000000"
                                            hex"00000000000000000000003e0000003f3435363738393a3b3c3d000000000000"
                                            hex"00000102030405060708090a0b0c0d0e0f101112131415161718190000000000"
                                            hex"001a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132330000000000";

    function encode(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return '';

        // load the table into memory
        string memory table = TABLE_ENCODE;

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((data.length + 2) / 3);

        // add some extra buffer at the end required for the writing
        string memory result = new string(encodedLen + 32);

        assembly {
            // set the actual output length
            mstore(result, encodedLen)

            // prepare the lookup table
            let tablePtr := add(table, 1)

            // input ptr
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))

            // result ptr, jump over length
            let resultPtr := add(result, 32)

            // run over the input, 3 bytes at a time
            for {} lt(dataPtr, endPtr) {}
            {
                // read 3 bytes
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)

                // write 4 characters
                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr( 6, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(        input,  0x3F))))
                resultPtr := add(resultPtr, 1)
            }

            // padding with '='
            switch mod(mload(data), 3)
            case 1 { mstore(sub(resultPtr, 2), shl(240, 0x3d3d)) }
            case 2 { mstore(sub(resultPtr, 1), shl(248, 0x3d)) }
        }

        return result;
    }

    function decode(string memory _data) internal pure returns (bytes memory) {
        bytes memory data = bytes(_data);

        if (data.length == 0) return new bytes(0);
        require(data.length % 4 == 0, "invalid base64 decoder input");

        // load the table into memory
        bytes memory table = TABLE_DECODE;

        // every 4 characters represent 3 bytes
        uint256 decodedLen = (data.length / 4) * 3;

        // add some extra buffer at the end required for the writing
        bytes memory result = new bytes(decodedLen + 32);

        assembly {
            // padding with '='
            let lastBytes := mload(add(data, mload(data)))
            if eq(and(lastBytes, 0xFF), 0x3d) {
                decodedLen := sub(decodedLen, 1)
                if eq(and(lastBytes, 0xFFFF), 0x3d3d) {
                    decodedLen := sub(decodedLen, 1)
                }
            }

            // set the actual output length
            mstore(result, decodedLen)

            // prepare the lookup table
            let tablePtr := add(table, 1)

            // input ptr
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))

            // result ptr, jump over length
            let resultPtr := add(result, 32)

            // run over the input, 4 characters at a time
            for {} lt(dataPtr, endPtr) {}
            {
               // read 4 characters
               dataPtr := add(dataPtr, 4)
               let input := mload(dataPtr)

               // write 3 bytes
               let output := add(
                   add(
                       shl(18, and(mload(add(tablePtr, and(shr(24, input), 0xFF))), 0xFF)),
                       shl(12, and(mload(add(tablePtr, and(shr(16, input), 0xFF))), 0xFF))),
                   add(
                       shl( 6, and(mload(add(tablePtr, and(shr( 8, input), 0xFF))), 0xFF)),
                               and(mload(add(tablePtr, and(        input , 0xFF))), 0xFF)
                    )
                )
                mstore(resultPtr, shl(232, output))
                resultPtr := add(resultPtr, 3)
            }
        }

        return result;
    }
}

contract NFTTicketingSystem is ERC721, Ownable {

    string public ImageURL;
    bool public areSalesActive; //Boolean informative if all sales are still running
    bool public OnPause; //Boolean informative if all sales are on pause for some reason
    bool public PrimarySale_SoldOut; //Boolean informative if Primary Sale is still runing
    uint256 public MintPrice; //Price (eth) to buy a ticket from Primary sale
    uint256 public Event_ID; //Unique identifier for each event
    uint256 public MaxSupply; //Each event is going to be of limited supply
    uint256 public counter_minted_per_event; // How many tickets have been minted for the specific event ID
    uint256 public sold_secondary; // How many tickets have been sold in secondary market
    mapping (uint256 => bool) public EventsHosted; //A track of all events ever hosted by this host


constructor() payable ERC721('Ticketing System', 'NFTICKETS') {
    

}
//https://gateway.pinata.cloud/ipfs/QmWWduVRyPCFxfxo3DKReKoSqQnSuvWx4LzGpZqer2Xk6r/1.jpg Link of an image that can be used for a ticket image

    struct TicketListing  {
        uint256 price;
        bool used;
        address seller;
        }

   function uint2str(uint _i) internal pure returns (string memory _uintAsString) { //https://stackoverflow.com/questions/47129173/how-to-convert-uint-to-string-in-solidity
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

//Only Owner

    mapping (uint256 => TicketListing) private tickets_for_sale;
    mapping (uint256 => bool) private UsedTickets;

    function toggleSaleStatus(uint256 _StatusCode) external onlyOwner { //Owner can define the status of the Sales at any given time.
        require(_StatusCode >= 0 && _StatusCode < 4, 'No such state has been encoded');
        if (_StatusCode == 0) areSalesActive = false;
        else if (_StatusCode == 1) {
            areSalesActive = true;
            OnPause = false;
        }
        else if (_StatusCode == 2)  PrimarySale_SoldOut = true;
        else if (_StatusCode == 3) {
        OnPause = !OnPause;
        if (OnPause) areSalesActive = false;
        } 
    }

    function toggleSaleParameters(uint256 MintPrice_, uint256 Event_ID_, uint256 MaxSupply_, string memory ImageURL_) external onlyOwner {
        require(!areSalesActive, 'Can not change sale parameters on an active sale.');     
        require(!EventsHosted[Event_ID_], 'An event with such an ID has already been hosted.');
        require(MaxSupply_ > 0, 'Please define an acceptable MaxSupply');
        require(Event_ID_ >= 0, 'Please define an acceptable Event ID');

        MintPrice = MintPrice_;
        Event_ID =  Event_ID_;
        MaxSupply = MaxSupply_;
        PrimarySale_SoldOut = false;
        EventsHosted[Event_ID_]=true;
        ImageURL= ImageURL_;
        counter_minted_per_event = 0;
    }

    function SetTicketToUsed(uint256 tickedID_) external onlyOwner {
        require (tickedID_ < Event_ID*1000 + counter_minted_per_event, 'This ticket has not been minted!');
        UsedTickets[tickedID_]=true;
    }

    function tokenURI(uint256 tokenId) override(ERC721) public view returns (string memory) {
            string memory json = Base64.encode(
                bytes(string(
                    abi.encodePacked(
                        '{"name": "Access Ticket",',
                        '"image": "',ImageURL,'",',
                    // '"image": "https://ipfs.io/ipfs/Qme7ss3ARVgxv6rXqVPiikMJ8u2NLgmgszg13pYrDKEoiu",',
                        '"attributes": [{"trait_type": "Event ID", "value": ', uint2str(Event_ID), '},',
                        '{"trait_type": "Ticket ID", "value": ', uint2str(tokenId), '}]}'
                    )
                ))
            );
            return string(abi.encodePacked('data:application/json;base64,', json));
        }    


    function withdraw() public payable onlyOwner {
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success);
    }

    //User
    
    function setTicketForSale (uint256 price, uint256 tokenID_) public {
        require(this.ownerOf(tokenID_) == msg.sender, 'You do not own the ticket you are trying to set for sale!');
        require(this.isApprovedForAll(msg.sender,(address(this))),'You need to approve the contract to be able to transfer the token in case of sale!');

        tickets_for_sale[tokenID_] = TicketListing(price,UsedTickets[tokenID_],msg.sender);
    }

    function purchaseTicket(uint256 tokenID_) public payable {
    require (tokenID_ < Event_ID*1000 + counter_minted_per_event, 'This ticket has not been minted!');
    require (tickets_for_sale[tokenID_].price > 0, 'This ticket is not for sale!');

    TicketListing memory ticket = tickets_for_sale[tokenID_];

    require (msg.value == ticket.price, 'Insuffiecient funds');

    this.safeTransferFrom(ticket.seller,msg.sender,tokenID_);
    address payable addr = payable(ticket.seller);

    addr.transfer(ticket.price);

    delete tickets_for_sale[tokenID_];
    sold_secondary = sold_secondary + 1;

    }

    function cancelTicketForSale (uint256 tokenID_) public {
        require (tokenID_ < Event_ID*1000 + counter_minted_per_event, 'This ticket has not been minted!');
        require (tickets_for_sale[tokenID_].price > 0, 'This ticket is not for sale!');
        require(this.ownerOf(tokenID_) == msg.sender, 'You do not own the ticket you are trying to cancel for sale!');
    

        delete tickets_for_sale[tokenID_];
    }

    function IsTicketUsed(uint256 Ticketid) external view 
        returns (
            bool used
            
        )
        {   
            require (Ticketid < Event_ID*1000 + counter_minted_per_event, 'This ticket has not been minted!');
            used = UsedTickets[Ticketid];

        }

    function IsTicketForSale(uint256 Ticketid) external view 
        returns (
            bool forsale,
            uint256 price
        )
        {   
            require (Ticketid <= Event_ID*1000 + counter_minted_per_event, 'This ticket has not been minted!');
            if (tickets_for_sale[Ticketid].price > 0 ) {
                forsale = true;
                price = tickets_for_sale[Ticketid].price;
                }
            else {
                forsale = false;
                price = 0;
            }

        }

    function mintTicket() external payable {
        
        require(areSalesActive, 'Can not purchase a ticket. Sale has not yet started!');
        require(msg.value == MintPrice, 'Trying to pay a wrong ticket price!');
        require (counter_minted_per_event < MaxSupply, 'SOLD OUT');
        _mint(msg.sender, Event_ID*1000 + counter_minted_per_event);
        counter_minted_per_event++;
        if (counter_minted_per_event == MaxSupply) PrimarySale_SoldOut = true;
    }


    }