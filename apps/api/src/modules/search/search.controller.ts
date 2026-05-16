import { Controller, Get, Query } from '@nestjs/common';
import { z } from 'zod';
import { ZodValidationPipe } from '../../shared/pipes/zod-validation.pipe';
import { SEARCH_TYPES, SearchEntityType } from './dto/search.dto';
import { SearchService } from './search.service';

const querySchema = z
  .object({
    q: z.string().min(1).max(200),
    types: z.string().max(200).optional(),
    limit: z.string().regex(/^\d+$/).optional(),
  })
  // Reject unknown keys so typos don't pass silently.
  .passthrough();

type SearchQuery = z.infer<typeof querySchema>;

@Controller()
export class SearchController {
  constructor(private readonly search: SearchService) {}

  @Get('search')
  async run(@Query(new ZodValidationPipe(querySchema)) query: SearchQuery) {
    const parsedTypes = parseTypesParam(query.types);
    const parsedLimit = query.limit ? Number(query.limit) : undefined;
    return this.search.searchAll(query.q, parsedTypes, parsedLimit);
  }

  @Get('search/suggestions')
  suggestions(@Query('categorySlug') categorySlug?: string) {
    return this.search.suggestionsFor(categorySlug);
  }
}

const KNOWN = new Set<string>(SEARCH_TYPES);

function parseTypesParam(raw?: string): SearchEntityType[] | null {
  if (!raw) return null;
  const parts = raw
    .split(',')
    .map((s) => s.trim())
    .filter((s) => s.length > 0 && KNOWN.has(s));
  return parts.length > 0 ? (parts as SearchEntityType[]) : null;
}
