set args ../tests/programs/struct_comparison.uya -o ../tests/programs/build/struct_comparison.o
break parser_parse_block
break parser_peek_is_struct_init
break parser_expect
break parser_parse_primary_expr
commands
  printf "parser_parse_primary_expr: current_token type=%d\n", parser->current_token->type
  continue
end
commands
  printf "parser_peek_is_struct_init called\n"
  printf "  current_token type=%d\n", parser->current_token->type
  printf "  lexer position=%zu\n", parser->lexer->position
  continue
end
commands
  printf "parser_parse_block: current_token type=%d\n", parser->current_token->type
  if parser->current_token != NULL
    printf "  value=%s\n", parser->current_token->value ? parser->current_token->value : "(null)"
  end
  continue
end
commands
  printf "parser_expect: expecting type=%d, current type=%d\n", type, parser->current_token->type
  if parser->current_token->type != type
    printf "  ERROR: type mismatch!\n"
    printf "  current_token value=%s\n", parser->current_token->value ? parser->current_token->value : "(null)"
    bt
  end
  continue
end
run

