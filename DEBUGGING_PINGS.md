# Debugging MeshCore Wardrive Ping Responses

## Expected Flow

When a ping is sent, this is what should happen:

### 1. Ping Sent
```
📍 Updated device position: lat, lon
📡 Sending zero-hop advertisement
📡 Sending DISCOVER_REQ with tag=0xXXXXXXXX
📍 Discovery ping sent at (lat, lon), waiting for responses...
```

### 2. Raw Data Received
```
📶 Raw RX: X bytes - [hex dump of first 20 bytes]
```

### 3. Frame Parsed
```
📥 RX Frame: code=0xXX (decimal) len=X
```

**Key frame codes to look for:**
- `0x84` (132 decimal) = **ACK** from repeater (this is what we want!)
- `0x8E` (142 decimal) = **Control Data** (could contain Discovery response)
- `0x80` (128 decimal) = Advertisement from repeater

### 4. ACK Processing (if 0x84 received)
```
✅ ACK from [REPEATER_ID] (SNR: X, RSSI: Y)
📞 Requesting position for [REPEATER_ID]
```

### 5. Discovery Response Processing (if 0x8E received)
```
🔍 DISCOVER_RESP: tag=0xXXXXXXXX, node=[ID], type=X, SNR=X, RSSI=X
📞 Requesting position for [ID]
```

### 6. Contact Response
```
Contact: [NAME] (type: 2)
✅ Added to map: [NAME] at (lat, lon)
```

### 7. Ping Complete
```
✅ Ping complete: X repeater(s) responded
✅ Best response: [ID] (SNR=X, RSSI=Y)
```

OR if no responses:
```
⏰ Ping timeout. No repeaters responded.
```

## Common Issues

### Issue 1: No Raw Data Received
**Symptom:** No `📶 Raw RX` messages after ping sent

**Possible causes:**
- LoRa device not actually connected
- Device in wrong mode (need to check USB vs BLE)
- Device not transmitting
- No repeaters in range

**Debug:**
- Check connection status in app
- Verify device shows as connected
- Try manual disconnect/reconnect
- Check device battery

### Issue 2: Raw Data Received But Not Parsed
**Symptom:** See `📶 Raw RX` but no `📥 RX Frame` messages

**Possible causes:**
- Protocol mode mismatch (BLE vs USB framing)
- Corrupted data
- Buffer synchronization issues

**Debug:**
- Check if USB or Bluetooth connection
- USB should have frames starting with `3E` ('>') 
- BLE should have unwrapped frames
- Look for parse errors in logs

### Issue 3: Frames Parsed But Wrong Type
**Symptom:** See `📥 RX Frame` but code is not 0x84 or 0x8E

**Common frame codes:**
- `0x00` (RESP_CODE_OK) - Command acknowledged
- `0x01` (RESP_CODE_ERR) - Command error
- `0x02` (RESP_CODE_APP_START) - Handshake complete
- `0x03` (RESP_CODE_CONTACT) - Contact info response
- `0x05` (RESP_CODE_SELF_INFO) - Device info
- `0x06` (RESP_CODE_SENT) - Message sent confirmation

**If seeing only OK/SENT responses:**
- Pings are being sent but repeaters aren't responding
- Could be out of range
- Could be no active repeaters nearby

### Issue 4: ACKs Received But No Position
**Symptom:** See `✅ ACK from [ID]` but repeater not added to map

**Possible causes:**
- Contact request not being sent
- Contact response not received
- Repeater has no position in its contact info
- Repeater is filtered (mobile repeater prefix match)

**Debug:**
- Look for `📞 Requesting position` message
- Look for `Contact: [ID]` response
- Check if position data is present (lat/lon)
- Check "Ignore Repeater Prefix" setting

### Issue 5: Discovery Responses With Unknown Tags
**Symptom:** `⚠️ Discovery response for unknown/completed tag`

**Possible causes:**
- Response arrived after timeout
- Tag mismatch (endianness issue)
- Multiple pings overlapping

**Debug:**
- Increase ping timeout from 10 to 20 seconds
- Check tag values in logs (should match)
- Ensure only one ping at a time

## Manual Testing Steps

### Test 1: Check Device Communication
1. Connect LoRa device
2. Watch for handshake: `✅ App handshake complete`
3. Should see: `✅ Command OK` or similar responses

### Test 2: Check Contact List Loading
1. Look for: `📒 Requesting full contact list...`
2. Should see: Multiple `Contact: [NAME]` messages
3. Should see: `Contact list complete`
4. If you see contacts with positions, device communication is working

### Test 3: Send Manual Ping
1. Enable auto-ping in app
2. Watch debug logs during ping
3. Note which messages appear

### Test 4: Check Response Timing
- Zero-hop adverts should trigger ACKs within 1-2 seconds
- Discovery responses may take 2-5 seconds
- Contact requests take 1-2 seconds per repeater
- Total expected time: 5-10 seconds per ping

## Protocol Frame Details

### ACK Frame (0x84) Structure
```
Byte 0-1:  SNR (signed int16)
Byte 2-3:  RSSI (signed int16)  
Byte 4-35: Public key (32 bytes)
```

### Control Data Frame (0x8E) Structure
```
Byte 0:    SNR/4 (signed int8)
Byte 1:    RSSI (signed int8)
Byte 2:    Path length
Byte 3+:   Path bytes (if any)
Byte X+:   Payload (Discovery response or other control data)
```

### Discovery Response Payload Structure
```
Byte 0:    Flags (upper 4 bits = 0x9 for DISCOVER_RESP, lower 4 bits = node type)
Byte 1:    SNR/4 (signed int8)
Byte 2-5:  Tag (uint32 little-endian)
Byte 6+:   Public key (8 or 32 bytes depending on prefixOnly flag)
```

## Key Settings to Check

1. **Ping Timeout**: Default 10 seconds (may need 20s in weak coverage)
2. **Ping Interval**: Default 805m (0.5 miles)
3. **Ignore Repeater Prefix**: Should be empty unless you have a mobile repeater
4. **Coverage Precision**: Default 6 (affects grid size, not responses)

## Expected Repeater Response Rate

In good conditions:
- **Direct range (zero-hop)**: 80-100% ACK rate
- **Via mesh (multi-hop)**: Discovery responses may be slower/unreliable
- **Urban area**: Expect 1-3 repeaters per ping
- **Rural area**: May be 0 repeaters (dead zones)

## Next Steps

If you're still not seeing responses:

1. **Capture full debug log** from one complete ping cycle
2. **Check what frame types** are being received (codes)
3. **Verify contact list loads** on initial connection
4. **Try in known coverage area** to rule out "no repeaters" issue
5. **Check device firmware** - may need MeshCore companion radio update

## Log Export

The app has a debug log screen. You can:
1. Go to settings/debug menu
2. View full log output
3. Look for the specific messages listed above
4. Share relevant log sections for further debugging
