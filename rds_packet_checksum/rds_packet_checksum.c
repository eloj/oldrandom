/*

 RVR Elettronica RDS packet checksum calculator
 reverse-engineered (R) 2007 by Eddy L O Jansson <eddy klopper net>

 2007-12-16  eloj  Noted the need for escapeing some bytes, and added
                   rds_packet_checksum_collide()
 2007-12-16  eloj  First version

*/
#include<stdio.h>
#include<stdint.h>
#include<stdlib.h>
#include<string.h>

static const int PKT_MAX_SIZE = 16;
static const int PKT_LEN_OFS = 4;
static const int PKT_PAY_OFS = 8;
                                                            /* len / cmd */
const unsigned char pkt_cmd01[] = { 0xFE, 0x00, 0x7F, 0x00, 0x05, 0x63, 0x00, 0x00, 0x00, 0x01, 0x0C, 0x0C, 0xFF };
      unsigned char pkt_cmd02[] = { 0xFE, 0x00, 0x00, 0x00, 0x0B, 0x02, 0x00, 0x00, ' ',' ',' ',' ',' ',' ',' ',' ',0 };


uint16_t swap(uint16_t word)
{
  return (word << 8) | (word >> 8);
}

uint16_t rds_packet_checksum(const char* str, uint8_t len)
{
  uint16_t chksum = 0xFFFF;

  for(int i=0 ; i<len ; ++i)
  {
    chksum  = swap(chksum) ^ str[i];
    chksum ^= (chksum & 0x00F0) >> 4;
    chksum ^= (swap(chksum & 0x00FF) ^ ((chksum & 0x00FF) << 1)) << 4;
  }
  return ~chksum;
}

/* If the checksum contains a 0xFF, 0xFE or 0xFD, it must be escaped.

 0xFFyy => 0xFD 0x02 0xyy
 
 0xFEyy => 0xFD 0x01 0xyy ?
 0xFDyy => 0xFD 0x00 0xyy ?
 0xFFFF => ??

 Some test vectors to validate the escape code:

  Payload   unescaped
 '00038899' => 0000

 '0004432c' => ff52
 '00000102' => fe73
 '00000111' => fd21

 '00004d7c' => 52ff
 '000078d8' => 52fe
 '00042413' => 52fd

 '00041759' => fdff
 '000407c4' => feff
 '000416c0' => ffff
 '0004fcc9' => fffe
 '00004f03' => fffd
*/

uint8_t rds_packet_escape(const uint16_t chksum, char* dest)
{
  // Not implemented yet.
  if( ((chksum & 0x00FF) >= 0xFD) || ( ((chksum >> 8) & 0x00FF) >= 0xFD) )
  {
    printf("WARNING: Checksum needs escaping, but not implemented yet!\n");
    return 1;
  }
  return 0;
}

/*
  Given a checksum, scan for a collision using strings of a zeropadded counter.
*/
uint32_t rds_packet_checksum_collide(uint16_t collide_checksum)
{
  uint32_t payload = 0;

  printf("Finding collision for checksum %04x\n", collide_checksum);
  do {
    sprintf(&pkt_cmd02[PKT_PAY_OFS], "%08x", payload);

    if( rds_packet_checksum(&pkt_cmd02[1], 4+pkt_cmd02[PKT_LEN_OFS]) == collide_checksum )
    {
      printf("Payload '%s' => %04x\n", &pkt_cmd02[PKT_PAY_OFS], collide_checksum );
      return payload;
    }

  } while( ++payload != 0);

  return payload;
}

int main(int argc, char* argv[])
{

  /* A hack: if first character is a zer0, then look for a checksum collision
     on first argument as the checksum in decimal. */
  if( argc>1 && argv[1][0] == '0' )
  {
    rds_packet_checksum_collide(atoi(argv[1]));
    return EXIT_SUCCESS;
  }

  /* Copy payload into packet from cmdline */
  int i = 1;
  int offset = 8;
  while( i<argc )
  {
    int to_copy = strlen(argv[i]) > PKT_MAX_SIZE-offset ? PKT_MAX_SIZE-offset : strlen(argv[i]);
    if( offset + to_copy <= PKT_MAX_SIZE ) strncpy(&pkt_cmd02[offset], argv[i], to_copy);
    offset += to_copy + 1;
    ++i;
  }

  uint16_t pkt_cmd02_chksum = rds_packet_checksum(&pkt_cmd02[1], 4+pkt_cmd02[PKT_LEN_OFS]);
  printf("Checksum pkt1 is %s\n", 0x2a6d == rds_packet_checksum(&pkt_cmd01[1], 4+pkt_cmd01[PKT_LEN_OFS]) ? "OK" : "INCORRECT!" );
  printf("Checksum pkt2: 0x%04x", pkt_cmd02_chksum);
  printf(", for payload '%s'\n", &pkt_cmd02[PKT_PAY_OFS]);

  rds_packet_escape(pkt_cmd02_chksum, NULL);

  return EXIT_SUCCESS;
}
