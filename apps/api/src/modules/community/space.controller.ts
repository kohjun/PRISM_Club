import { Controller, Get, Query, BadRequestException } from '@nestjs/common';
import { CurrentUser, RequestUser } from '../../shared/decorators/current-user.decorator';
import { SpaceService } from './space.service';
import { CategoryService } from './category.service';

@Controller()
export class SpaceController {
  constructor(
    private readonly spaces: SpaceService,
    private readonly categories: CategoryService,
  ) {}

  @Get('spaces')
  async listSpaces() {
    return { items: await this.spaces.listSpaces() };
  }

  @Get('categories')
  async listCategories(
    @CurrentUser() user: RequestUser,
    @Query('spaceSlug') spaceSlug?: string,
  ) {
    if (!spaceSlug) {
      throw new BadRequestException('spaceSlug query param is required');
    }
    return { items: await this.categories.listBySpaceSlug(spaceSlug, user) };
  }
}
